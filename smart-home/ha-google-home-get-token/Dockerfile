FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir glocaltokens
COPY get_tokens.py .
CMD ["python3", "get_tokens.py"]
