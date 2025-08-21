from slowapi import Limiter
from slowapi.util import get_remote_address

# Create a Limiter instance that uses the client's IP address as the key.
limiter = Limiter(key_func=get_remote_address)
