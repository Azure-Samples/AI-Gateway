import datetime
import time
from urllib.parse import urlparse
from openai.types.chat import ChatCompletionMessage
from openai.types.chat.chat_completion import ChatCompletion, Choice

from flask import (Flask, redirect, render_template, request, make_response,
                   send_from_directory, url_for)
from transformers import AutoTokenizer, AutoModelForCausalLM, AutoConfig
import torch

app = Flask(__name__)

# Load the model and tokenizer from the Hugging Face model hub

model = AutoModelForCausalLM.from_pretrained("microsoft/Phi-3-mini-4k-instruct", torch_dtype="auto", trust_remote_code=True)
tokenizer = AutoTokenizer.from_pretrained("microsoft/Phi-3-mini-4k-instruct", trust_remote_code=True)

print("Pretained tokenizer and model loaded...")


@app.route('/')
def index():
    return {"message": "phy-3-mini SLM is running. Open http://aka.ms/ai-gateway for information on how to use."}

# OpenAI compatibility with the completions API
@app.route("/openai/deployments/<deployment_name>/chat/completions", methods=['POST'])
def completions(deployment_name):
    hostname = urlparse(request.base_url).hostname


    json_data = request.get_json(silent=True)

    try:
        messages = json_data.get("messages")
        template = "{% for message in messages %}{{'<|' + message['role'] + '|>' + '\n' + message['content'] + '<|end|>\n' }}{% endfor %}"
        max_tokens = 200
        temperature = 0.6

        if messages:


            print("[", datetime.datetime.now().time(),"] Received request from ",request.remote_addr," with the following messages: ",messages)

            tokenizer.chat_template = template
            tokenized_chat = tokenizer.apply_chat_template(messages, tokenize=True, add_generation_prompt=True, return_tensors="pt")
            outputs = model.generate(tokenized_chat, max_new_tokens=max_tokens, eos_token_id=32007)  # 32007 corresponds to <|end|>
            completion_text = tokenizer.batch_decode(outputs)[0]

            completion = ChatCompletion(
                id="foo",
                model=deployment_name,
                object="chat.completion",
                choices=[
                    Choice(
                        finish_reason="stop",
                        index=0,
                        message=ChatCompletionMessage(
                            content=completion_text,
                            role="assistant",
                        ),
                    )
                ],
                created=int(datetime.datetime.now().timestamp()),
            )
            response = make_response(completion.model_dump_json())
        else:
            response = make_response({'error': {'code': '500', 'message': 'The prompt was not provided.'}})

    except Exception as e:
        print("Error: ", e)
        response = make_response({'error': {'code': '500', 'message': 'An error occurred.'}})

    response.headers["x-ms-region"] = hostname
    return response

if __name__ == '__main__':
   app.run()



