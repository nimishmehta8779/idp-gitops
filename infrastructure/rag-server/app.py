import os
import glob
import json
import logging
import time
import requests
import psycopg2
from psycopg2.extras import RealDictCursor
from mcp.server.fastmcp import FastMCP
import uvicorn

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("rag-server")

# Database configurations from environment
DB_HOST = os.getenv("POSTGRES_HOST", "backstage-db")
DB_PORT = os.getenv("POSTGRES_PORT", "5432")
DB_USER = os.getenv("POSTGRES_USER", "postgres")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgrespassword")
DB_NAME = os.getenv("POSTGRES_DB", "backstage_plugin_catalog")

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")

# Initialize FastMCP Server
mcp = FastMCP("rag")
mcp.settings.transport_security.enable_dns_rebinding_protection = False


def get_db_connection():
    """Establish a connection to the PostgreSQL database."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursor_factory=RealDictCursor
    )

def get_embedding(text: str) -> list[float]:
    """Call Google Gemini embedding API to get vector representation of text."""
    if not GOOGLE_API_KEY:
        raise ValueError("GOOGLE_API_KEY environment variable is not set")
    
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key={GOOGLE_API_KEY}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "model": "models/gemini-embedding-001",
        "content": {
            "parts": [{"text": text}]
        }
    }
    
    response = requests.post(url, headers=headers, json=payload, timeout=10.0)
    response.raise_for_status()
    return response.json()["embedding"]["values"]

# --- MCP Tools ---

@mcp.tool()
async def search_knowledge_base(query: str, limit: int = 3) -> str:
    """Search the internal documentation and knowledge base for relevant information.
    
    Args:
        query: The semantic search query or question to lookup in the documentation database.
        limit: Max number of relevant documents/chunks to return (default 3).
    """
    logger.info(f"Received search request for query: '{query}'")
    try:
        query_vector = get_embedding(query)
    except Exception as e:
        logger.error(f"Failed to generate embedding for query: {e}")
        return f"Error: Failed to process search query embeddings. {e}"

    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            # Query pgvector using cosine distance (<=> operator)
            # The query_vector is converted to a string of float array format: '[0.1, 0.2, ...]'
            vector_str = "[" + ",".join(map(str, query_vector)) + "]"
            cur.execute("""
                SELECT content, metadata, (embedding <=> %s::vector) AS distance
                FROM caipe_rag_documents
                ORDER BY distance ASC
                LIMIT %s;
            """, (vector_str, limit))
            
            rows = cur.fetchall()
        conn.close()
        
        if not rows:
            return "No matching documentation found in the knowledge base."
            
        results = []
        for i, row in enumerate(rows, 1):
            metadata = row["metadata"] or {}
            filepath = metadata.get("filepath", "Unknown source")
            distance = row["distance"]
            similarity = round(1 - distance, 3)
            
            results.append(
                f"### Result {i} (Source: {filepath}, Similarity: {similarity})\n"
                f"{row['content']}\n"
            )
            
        return "\n---\n".join(results)
    except Exception as e:
        logger.error(f"Database query failed: {e}")
        return f"Error querying database: {e}"

@mcp.tool()
async def fetch_document(filepath: str) -> str:
    """Retrieve the full text content of a specific documentation file by its path.
    
    Args:
        filepath: The filepath of the document to retrieve (e.g., 'docs/eks-grant-access.md').
    """
    logger.info(f"Fetching document: {filepath}")
    # First, try to read from the local file system (most up-to-date)
    # The container mounts /development and /docs
    resolved_path = None
    if filepath.startswith("docs/"):
        resolved_path = os.path.join("/", filepath)
    elif filepath.startswith("development/"):
        resolved_path = os.path.join("/", filepath)
    else:
        # Fallback search
        for prefix in ["/docs", "/development"]:
            test_path = os.path.join(prefix, filepath.replace("docs/", "").replace("development/", ""))
            if os.path.exists(test_path):
                resolved_path = test_path
                break
                
    if resolved_path and os.path.exists(resolved_path):
        try:
            with open(resolved_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            logger.warning(f"Failed to read file {resolved_path} from disk: {e}")

    # Database fallback if file is not locally accessible
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT content FROM caipe_rag_documents
                WHERE metadata->>'filepath' = %s
                LIMIT 1;
            """, (filepath,))
            row = cur.fetchone()
        conn.close()
        if row:
            return row["content"]
    except Exception as e:
        logger.error(f"Database fallback query failed: {e}")

    return f"Error: Document '{filepath}' not found on disk or in the database."

# --- Document Indexing Pipeline ---

def chunk_text(text: str, chunk_size: int = 800, overlap: int = 150) -> list[str]:
    """Split text into overlapping chunks of rough chunk_size characters."""
    paragraphs = text.split("\n\n")
    chunks = []
    current_chunk = []
    current_size = 0
    
    for para in paragraphs:
        para_size = len(para)
        if para_size > chunk_size:
            # Paragraph is too large, split it by sentences/lines
            lines = para.split("\n")
            for line in lines:
                if current_size + len(line) > chunk_size and current_chunk:
                    chunks.append("\n".join(current_chunk))
                    # simple overlap: keep last 1-2 lines
                    current_chunk = current_chunk[-1:] if len(current_chunk) > 1 else []
                    current_size = sum(len(l) for l in current_chunk)
                current_chunk.append(line)
                current_size += len(line)
        else:
            if current_size + para_size > chunk_size and current_chunk:
                chunks.append("\n".join(current_chunk))
                # simple overlap
                current_chunk = current_chunk[-1:] if len(current_chunk) > 1 else []
                current_size = sum(len(p) for p in current_chunk)
            current_chunk.append(para)
            current_size += para_size
            
    if current_chunk:
        chunks.append("\n".join(current_chunk))
    return chunks

def index_all_markdown_files():
    """Find and index all markdown documentation files in mounted paths."""
    logger.info("Starting markdown document indexing...")
    
    # Paths to scan inside container
    paths_to_scan = [
        "/docs/**/*.md",
        "/development/**/*.md",
    ]
    
    files_to_index = []
    for pattern in paths_to_scan:
        files_to_index.extend(glob.glob(pattern, recursive=True))
        
    logger.info(f"Found {len(files_to_index)} markdown files to index.")
    
    conn = get_db_connection()
    
    for filepath in files_to_index:
        try:
            # Clean path to match workspace layout (e.g. /docs/x.md -> docs/x.md)
            clean_path = filepath.lstrip("/")
            
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
                
            logger.info(f"Indexing {clean_path} (length: {len(content)} characters)...")
            
            chunks = chunk_text(content)
            logger.info(f"Split {clean_path} into {len(chunks)} chunks.")
            
            # Determine domain/tags based on filepath
            domain = "general"
            technology = []
            if "eks" in clean_path or "cluster" in clean_path:
                domain = "infrastructure"
                technology = ["eks", "kubernetes", "aws"]
            elif "rbac" in clean_path or "permission" in clean_path:
                domain = "security"
                technology = ["rbac", "security", "backstage"]
                
            metadata = {
                "filepath": clean_path,
                "domain": domain,
                "technology": technology,
                "last_updated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(os.path.getmtime(filepath)))
            }
            
            # Remove old chunks for this file to prevent duplicates
            with conn.cursor() as cur:
                cur.execute("DELETE FROM caipe_rag_documents WHERE metadata->>'filepath' = %s", (clean_path,))
            
            for idx, chunk in enumerate(chunks):
                try:
                    vector = get_embedding(chunk)
                    vector_str = "[" + ",".join(map(str, vector)) + "]"
                    
                    with conn.cursor() as cur:
                        cur.execute("""
                            INSERT INTO caipe_rag_documents (content, embedding, metadata)
                            VALUES (%s, %s::vector, %s);
                        """, (chunk, vector_str, json.dumps(metadata)))
                except Exception as e:
                    logger.error(f"Failed to index chunk {idx} of {clean_path}: {e}")
                    
            conn.commit()
            logger.info(f"Successfully finished indexing {clean_path}")
        except Exception as e:
            logger.error(f"Failed to read/index file {filepath}: {e}")
            
    conn.close()
    logger.info("Document indexing process finished.")

# Run ASGI server
app = mcp.streamable_http_app()

# Add custom healthz endpoint for CAIPE connection check
from starlette.routing import Route as _Route
from starlette.responses import JSONResponse as _JSONResponse

async def _healthz(request):
    return _JSONResponse({"status": "ok"})

app.routes.append(_Route("/healthz", _healthz, methods=["GET"]))

if __name__ == "__main__":
    # Run indexing in a background thread so it doesn't block the ASGI web server startup health checks
    import threading
    logger.info("Launching background document indexing thread...")
    threading.Thread(target=index_all_markdown_files, daemon=True).start()
    
    uvicorn.run(app, host="0.0.0.0", port=9446)
