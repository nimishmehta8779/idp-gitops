FROM python:3.11-slim

WORKDIR /app

# Install standard dependencies
RUN pip install --no-cache-dir \
    mcp \
    psycopg2-binary \
    requests \
    uvicorn \
    starlette

# Copy app script
COPY app.py /app/app.py

EXPOSE 9446

CMD ["python", "app.py"]
