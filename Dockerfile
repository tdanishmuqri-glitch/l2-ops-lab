FROM python:3.12-slim
WORKDIR /srv
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ app/
COPY sql/ sql/
ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION} PORT=8080
EXPOSE 8080
# non-root user: basic container hardening
RUN useradd -m appuser && chown -R appuser /srv
USER appuser
HEALTHCHECK --interval=15s --timeout=3s CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8080/health')"
CMD ["gunicorn", "-w", "1", "--threads", "4", "-b", "0.0.0.0:8080", "app.main:app"]
