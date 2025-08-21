from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Loads and validates application settings from environment variables or a .env file.
    """
    OPENAI_API_KEY: str = "YOUR_API_KEY_HERE"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding='utf-8', extra='ignore')


settings = Settings()
