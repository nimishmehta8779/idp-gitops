# ${{ values.serviceName }}

${{ values.description }}

Welcome to the documentation site for the `${{ values.serviceName }}` service!

## Development

To run this service locally, clone the repository and run the setup scripts:

```bash
# Clone the repository
git clone https://github.com/nimishmehta8779/${{ values.repoName }}.git
cd ${{ values.repoName }}

# Start development server
npm install
npm run dev
```

## Features
- Modular microservice structure
- Native CI/CD pipeline integrated with GitHub Actions
- Catalog integration with Backstage out of the box
