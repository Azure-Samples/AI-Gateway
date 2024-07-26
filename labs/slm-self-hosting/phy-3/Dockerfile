FROM python:3.8-slim-buster

WORKDIR /usr/src/app

COPY requirements.txt ./

RUN pip3 install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

ENV FLASK_APP=app.py
ENV HF_HOME=/model_cache

CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
