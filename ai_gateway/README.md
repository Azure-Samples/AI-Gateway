# Modular AI Gateway

Este projeto é um AI Gateway modular e auto-contido, construído com Python e FastAPI. Ele foi projetado para ser um ponto de entrada centralizado para vários modelos de linguagem (LLMs), oferecendo funcionalidades como roteamento, rate limiting e autenticação em um único lugar.

A aplicação é baseada nos conceitos e padrões explorados no repositório [Azure/AI-Gateway](https://github.com/Azure-Samples/AI-Gateway), mas foi reimplementada como uma aplicação Python independente, agnóstica de nuvem e pronta para ser containerizada.

## Funcionalidades

*   **API Unificada:** Um único endpoint (`/v1/chat/completions`) para interagir com diferentes modelos de IA.
*   **Abstração de Provedores:** Arquitetura modular que permite adicionar facilmente novos provedores de IA (atualmente suporta OpenAI).
*   **Rate Limiting:** Controle de taxa de requisições por IP (configurado para 5 requisições por minuto).
*   **Containerização:** Pronto para ser executado com Docker, facilitando a implantação.
*   **Configuração Simples:** Gerenciamento de configurações através de variáveis de ambiente e arquivos `.env`.

## Pré-requisitos

*   Python 3.11+
*   Docker (opcional, para execução em container)

## 1. Configuração do Ambiente

Primeiro, clone o repositório e instale as dependências.

```bash
# Clone este repositório (se ainda não o fez)
# git clone <url-do-repositorio>
# cd <diretorio-do-repositorio>

# Crie um ambiente virtual (recomendado)
python -m venv venv
source venv/bin/activate  # No Windows, use `venv\Scripts\activate`

# Instale as dependências
pip install -r requirements.txt
```

## 2. Configuração da Aplicação

A aplicação precisa de uma chave de API para se comunicar com a OpenAI.

1.  **Crie o arquivo `.env`:**
    Copie o arquivo de exemplo ou crie um novo na raiz do projeto.

    ```bash
    cp .env.example .env
    ```
    *(Nota: Como não criamos um `.env.example`, você pode criar o arquivo `.env` manualmente)*

2.  **Adicione sua API Key:**
    Abra o arquivo `.env` e adicione sua chave da OpenAI:
    ```
    OPENAI_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    ```

## 3. Executando a Aplicação

Você pode executar o AI Gateway localmente com Uvicorn ou via Docker.

### Localmente com Uvicorn

```bash
uvicorn ai_gateway.main:app --reload
```

A API estará disponível em `http://127.0.0.1:8000`.

### Com Docker

Certifique-se de que o Docker está em execução.

```bash
# Construa a imagem do Docker
docker build -t ai-gateway .

# Execute o container
docker run -p 8000:8000 -d --name my-ai-gateway ai-gateway
```

A API estará disponível em `http://localhost:8000`.

## 4. Testando a API

Você pode usar `curl` ou qualquer cliente de API para testar o endpoint.

```bash
curl -X POST "http://localhost:8000/v1/chat/completions" \
-H "Content-Type: application/json" \
-d '{
    "model": "gpt-4o-mini",
    "messages": [
        {
            "role": "user",
            "content": "Olá! Qual é a capital do Brasil?"
        }
    ]
}'
```

## 5. Executando os Testes

Para garantir que tudo está funcionando corretamente, você pode executar a suíte de testes automatizados.

```bash
python -m pytest
```
