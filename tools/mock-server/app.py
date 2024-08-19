import datetime
import time
from urllib.parse import urlparse
from openai.types.chat import ChatCompletionMessage
from openai.types.chat.chat_completion import ChatCompletion, Choice

from flask import (Flask, redirect, render_template, request, make_response,
                   send_from_directory, url_for)

app = Flask(__name__)


@app.route('/')
def index():
    return {"message": "OpenAI Mock service is running. Open http://aka.ms/ai-gateway for information on how to use."}

# https://github.com/openai/openai-python/issues/398
@app.route("/openai/deployments/<deployment_name>/chat/completions", methods=['POST'])
def completions(deployment_name):
    hostname = urlparse(request.base_url).hostname
    json = request.get_json(silent=True)
    if json is None:
        return {"message": "No JSON data found in the request"}, 400
    print("[", datetime.datetime.now().time(),"] Received request from ",request.remote_addr," with the following data: ",request.json)
    try:
        response_status_code = request.json["messages"][0]["content"]["simulation"][hostname]["response_status_code"]
    except:
        response_status_code = request.json["messages"][0]["content"]["simulation"]["default"]["response_status_code"]
    try:
        wait_time_ms = request.json["messages"][0]["content"]["simulation"][hostname]["wait_time_ms"]/1000
    except:
        wait_time_ms = request.json["messages"][0]["content"]["simulation"]["default"]["wait_time_ms"]/1000
    if wait_time_ms > 0:
        time.sleep(wait_time_ms)
    if response_status_code < 400:
        completion = ChatCompletion(
            id="foo",
            model=deployment_name,
            object="chat.completion",
            choices=[
                Choice(
                    finish_reason="stop",
                    index=0,
                    message=ChatCompletionMessage(
                        content="Mock response from " + hostname,
                        role="assistant",
                    ),
                )
            ],
            created=int(datetime.datetime.now().timestamp()),
        )
        response = make_response(completion.model_dump_json())
        response.headers["x-ratelimit-remaining-tokens"] = "5000"
        response.headers["x-ratelimit-remaining-requests"] = "50"
    elif response_status_code == 429:
        response = make_response({'error': {'code': '429', 'message': 'Rate limit is exceeded. Try again in 5 seconds.'}})
        response.headers["retry_after_ms"] = "5000"
    elif response_status_code == 500:
        response = make_response({'error': {'code': '500', 'message': 'Internal server error'}})
    elif response_status_code == 503:
        response = make_response({'error': {'code': '503', 'message': 'The engine is currently overloaded, please try again later'}})
    else:
        response = make_response({'error': {'code': response_status_code, 'message': 'Unknown error'}})
    response.status_code = response_status_code
    response.headers["x-ms-region"] = hostname
    return response

if __name__ == '__main__':
   app.run()



