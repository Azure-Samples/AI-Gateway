import azure.functions as func
import datetime
import json
import logging

app = func.FunctionApp()

@app.route(route="weather", auth_level=func.AuthLevel.ANONYMOUS)
def weather(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    try:
        req_body = req.get_json()
    except ValueError:
        pass
    else:
        location = req_body.get('location')
        unit = req_body.get('unit')

    if "lisbon" in location.lower():
        temperaure = 29
    if "tokyo" in location.lower():
        temperaure = 10
    elif "san francisco" in location.lower():
        temperaure = 72
    elif "paris" in location.lower():
        temperaure = 22
    else:
        temperaure = 20

    reponse = {
        'location': location,
        'unit': unit,
        'temperature': temperaure
    }
               
    if location:
        return func.HttpResponse(json.dumps(reponse))
    else:
        return func.HttpResponse(
             "{error: 'Please pass a location in the request body'}",
             status_code=200
        )