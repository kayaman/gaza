#!/bin/bash

# create project folders structure

mkdir -p docs/diagrams
mkdir -p architecture/diagrams
mkdir -p infrastructure/aws/{cloudformation,terraform,cdk}
mkdir -p infrastructure/aws/cdk/constructs
mkdir -p infrastructure/aws/terraform/modules/{lambda,dynamodb,api-gateway}
mkdir -p infrastructure/{vercel,docker}
mkdir -p infrastructure/vercel/api
mkdir -p configurations
mkdir -p backend/lambda/src/{handlers,services,utils}
mkdir -p backend/lambda/tests/{handlers,services,integration}
mkdir -p backend/vercel/api
mkdir -p backend/shared/{crypto,constants,types}
mkdir -p client/postman/{collections,environments,scripts}
mkdir -p web/{public,src}
mkdir -p cli/{src,bin}
mkdir -p security/{domains,totp,opsec,policies}
mkdir -p monitoring/{cloudwatch,scripts,alerts}
mkdir -p scripts/{deployment,maintenance,testing,development}
mkdir -p config/{aws,security,environments}
mkdir -p tests/{unit,integration,performance,security}
mkdir -p tools/{generators,validator,utilities}

# create project files
touch README.md
touch LICENSE
touch .gitignore
touch .env.sample

touch docs/ARCHITECTURE.md
touch docs/SECURITY.md
touch docs/DEPLOYMENT.md
touch docs/API.md
touch docs/TROUBLESHOOTING.md

touch infrastructure/aws/cloudformation/{lambda-function.yaml,api-gateway.yaml,dynamodb-table.yaml,iam-role.yaml}
touch infrastructure/aws/terraform/{lambda-function.tf,api-gateway.tf,dynamodb-table.tf,iam-role.tf}
touch infrastructure/aws/cdk/{app.ts,variables.tf,outputs.ts}
touch infrastructure/vercel/vercel.json
touch infrastructure/vercel/api/chat.ts
touch infrastructure/docker/{Dockerfile,docker-compose.yaml,nginx.conf}

touch backend/lambda/src/handlers/{chat.ts,history.ts,health.ts}
touch backend/lambda/src/services/{encryption.ts,totp.ts,anthropic.ts,storage.ts}
touch backend/lambda/src/utils/{logger.ts,validators.ts,errors.ts}
touch backend/lambda/src/utils/index.ts

touch backend/vercel/{package.json,tsconfig.json}
touch backend/vercel/api/chat.ts