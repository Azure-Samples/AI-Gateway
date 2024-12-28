import azure.functions as func
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

    reponse = {
        'location': location,
        'unit': unit,
        'temperature': get_temperature(location)
    }

    if location:
        return func.HttpResponse(json.dumps(reponse))
    else:
        return func.HttpResponse(
             "{error: 'Please pass a location in the request body'}",
             status_code=200
        )

def get_temperature(location):
    match location.lower():
        case 'lisbon':
            return 29
        case 'london':
            return 22
        case 'tokyo':
            return 10
        case 'san francisco':
            return 72
        case 'new york city':
            return 74
        case 'new york':
            return 74
        case 'sydney':
            return 25
        case 'paris':
            return 21
        case _:
            return 20
