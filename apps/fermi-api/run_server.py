"""Script to run the Guesstimate Game backend server."""

import uvicorn
from fermi_core import setup_logging

# Configure logging
setup_logging()

if __name__ == '__main__':
    uvicorn.run('main:app', host='0.0.0.0', port=8000, reload=True, proxy_headers=True)  # noqa: S104
