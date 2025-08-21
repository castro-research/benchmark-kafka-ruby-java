# Build

docker build -t chart-runner .

# Gerar 

docker run --rm -it -v "$PWD":/app -w /app chart-runner python output.py
