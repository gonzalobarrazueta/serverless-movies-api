from azure.storage.blob import BlobServiceClient, ContentSettings
from huggingface_hub import InferenceClient
from azure.cosmos import CosmosClient
from io import BytesIO
import azure.functions as func
import logging
import json
import uuid
import os

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="add-movie", methods=["POST"])
@app.cosmos_db_output(arg_name="outputDocument", database_name="movies", container_name="movies", connection="CosmosDbConnectionSetting")
def add_movie(req: func.HttpRequest, outputDocument: func.Out[func.Document]) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    # Uploads the movie poster to an Azure Storage Account
    try:
        poster = req.files.get('poster')
    
        if not poster:
            return func.HttpResponse("Missing required argument: poster.", status_code=400)

        filename = poster.filename
        file_content = poster.stream.read()

        logging.info(f'Received image: {filename}, size: {len(file_content)} bytes.')

        connection_string = os.environ['BlobConnectionSetting']

        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        blob_client = blob_service_client.get_blob_client(container="movie-posters", blob=filename)
        blob_client.upload_blob(
            BytesIO(file_content),
            overwrite=False,
            content_settings=ContentSettings(content_type=poster.mimetype))
    except:
        return func.HttpResponse(status_code=400)
    
    # Uploads a movie document to Cosmos DB
    try:
        title = req.form.get('title')
        release_year = req.form.get('year')
        genre = req.form.get('genre')
        poster = blob_client.url
        logging.info(f'Poster url: {poster}')
    
        if not title or not release_year or not genre:
            return func.HttpResponse("Missing one or multiple required arguments.", status_code=400)
        
        if not poster or poster == "":
            return func.HttpResponse("Invalid movie poster url.", status_code=400)
        
        outputDocument.set(func.Document.from_dict({
            "id": str(uuid.uuid4()),
            "title": title,
            "release_year": release_year,
            "genre": genre,
            "poster": poster
        }))
    except ValueError:
        return func.HttpResponse(status_code=400)
    else:   
        return func.HttpResponse(f"Movie '{title}' added successfully 📽️", status_code=200)
    
@app.route(route="get_movies", methods=["GET"])
def get_movies(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    connection_string = os.environ["CosmosDbConnectionSetting"]
    cosmos_client = CosmosClient.from_connection_string(connection_string)

    try:
        database_client = cosmos_client.get_database_client("movies")
        container_client = database_client.get_container_client("movies")
    except Exception as e:
        return func.HttpResponse(f'An unexpected error occurred: {str(e)}', status_code=400)

    try:
        documents = list(container_client.query_items(
            "SELECT m.title, m.release_year, m.genre, m.poster FROM m",
            enable_cross_partition_query=True
            ))
        movies_json = json.dumps(documents, indent=True)
        
        for doc in documents:
            print(doc)
        
        return func.HttpResponse(movies_json, mimetype="application/json", status_code=200)
    except Exception as e:
        return func.HttpResponse(f'Error: {e}', status_code=400)
    
@app.route(route="get_movies_by_year", methods=["GET"])
def get_movies_by_year(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    connection_string = os.environ["CosmosDbConnectionSetting"]
    cosmos_client = CosmosClient.from_connection_string(connection_string)

    database_client = cosmos_client.get_database_client("movies")
    container_client = database_client.get_container_client("movies")
    
    year = req.params.get('year')

    if not year:
        return func.HttpResponse("Missing 'year' query parameter.", status_code=400)

    try:
        documents = list(container_client.query_items(
            "SELECT m.title, m.release_year, m.genre, m.poster FROM m WHERE m.release_year = @year",
            parameters=[dict(name="@year", value=year)],
            enable_cross_partition_query=True
            ))
        
        movies_json = json.dumps(documents, indent=True)
        
        for doc in documents:
            print(doc)
        
        return func.HttpResponse(movies_json, mimetype="application/json", status_code=200)
    except Exception as e:
        return func.HttpResponse(f'Error: {e}', status_code=400)

@app.route(route="generate-summary", methods=["POST"])
def generate_summary(req: func.HttpRequest) -> func.HttpResponse:
    
    body = req.get_json()

    movie = body.get('movie')
    year = body.get('year')

    if not movie or not year:
        return func.HttpResponse("Movie or year missing from request body", status_code=400)

    client = InferenceClient(
        provider = 'novita',
        api_key = os.environ['HuggingFaceAPIKey']
    )

    try:
        completion = client.chat.completions.create(
            model = os.environ['HuggingFaceAIModel'],
            messages = [
                {
                    "role": "user",
                    "content": f'Write a short summary of the movie {movie} released in {year}. Focus only on the plot, and avoid mentioning actors, directors, source material, or production details. The summary must be concise and no longer than 4 sentences.'
                }
            ],
            max_tokens = 240
        )

        summary = completion.choices[0].message.content
        
        if summary is None:
            return func.HttpResponse("Oops! Our AI is couldn't summarize that film. Try again in a bit!")
        else:
            return func.HttpResponse(summary, status_code=200)
        
    except Exception as e:
        logging.error(f"Failed to generate movie summary: {e}")

        return func.HttpResponse(
            "Oops! Something went wrong while talking to the AI. Please try again later.",
            status_code=500
        )
    