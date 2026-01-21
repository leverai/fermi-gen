"""GCS upload utilities for video-gen job."""

import logging
from pathlib import Path

from google.cloud import storage

logger = logging.getLogger(__name__)


def upload_to_gcs(
    local_path: Path,
    bucket_name: str,
    destination_blob_name: str,
) -> str:
    """Upload a file to Google Cloud Storage.

    Args:
        local_path: Path to the local file to upload.
        bucket_name: Name of the GCS bucket.
        destination_blob_name: Destination path within the bucket.

    Returns:
        The GCS URI of the uploaded file.

    """
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    logger.info(
        'Uploading to GCS',
        extra={
            'local_path': str(local_path),
            'bucket': bucket_name,
            'blob': destination_blob_name,
        },
    )

    blob.upload_from_filename(str(local_path))

    gcs_uri = f'gs://{bucket_name}/{destination_blob_name}'
    logger.info('Upload complete', extra={'gcs_uri': gcs_uri})

    return gcs_uri
