# Use an official Python runtime as a parent image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container at /app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code into the container at /app
COPY ./ai_gateway ./ai_gateway
COPY .env .

# Make port 8000 available to the world outside this container
EXPOSE 8000

# Run uvicorn when the container launches
# --host 0.0.0.0 is required to make the app accessible from outside the container
CMD ["uvicorn", "ai_gateway.main:app", "--host", "0.0.0.0", "--port", "8000"]
