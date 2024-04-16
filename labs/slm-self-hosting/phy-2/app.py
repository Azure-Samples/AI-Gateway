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
tokenizer = AutoTokenizer.from_pretrained("microsoft/phi-2")
tokenizer.pad_token = tokenizer.eos_token
tokenizer.padding_side = 'left'
config = AutoConfig.from_pretrained("microsoft/phi-2")
model = AutoModelForCausalLM.from_pretrained("microsoft/phi-2", config=config)

print("Pretained tokenizer and model loaded...")


@app.route('/')
def index():
    return {"message": "phy-2 SLM is running. Open http://aka.ms/ai-gateway for information on how to use."}

# OpenAI compatibility with the completions API
@app.route("/openai/deployments/<deployment_name>/chat/completions", methods=['POST'])
def completions(deployment_name):
    hostname = urlparse(request.base_url).hostname
    json = request.get_json(silent=True)
    if json is None:
        return {"message": "No JSON data found in the request"}, 400
    prompt = request.json["messages"][0]["content"]

    if prompt:
        print("[", datetime.datetime.now().time(),"] Received request from ",request.remote_addr," with the following prompt: ",prompt)

        input_ids = tokenizer.encode(prompt, return_tensors='pt', padding='max_length', truncation=True, max_length=512)

        attention_mask = input_ids.ne(tokenizer.pad_token_id).int()

        output = model.generate(input_ids=input_ids, attention_mask=attention_mask, pad_token_id=tokenizer.eos_token_id, temperature=0.6, num_return_sequences=1, top_p=0.95, top_k=50, do_sample=True, max_new_tokens=50)
        
        completion_content = tokenizer.decode(output[0], skip_special_tokens=True)
        completion = ChatCompletion(
            id="foo",
            model=deployment_name,
            object="chat.completion",
            choices=[
                Choice(
                    finish_reason="stop",
                    index=0,
                    message=ChatCompletionMessage(
                        content=completion_content,
                        role="assistant",
                    ),
                )
            ],
            created=int(datetime.datetime.now().timestamp()),
        )
        response = make_response(completion.model_dump_json())
    else:
        response = make_response({'error': {'code': '500', 'message': 'The prompt was not provided.'}})

    response.headers["x-ms-region"] = hostname
    return response

if __name__ == '__main__':
   app.run()



