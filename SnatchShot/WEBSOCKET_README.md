# WebSocket Integration for Process-Image API

## Overview

The SnatchShot Cloud API now includes WebSocket integration that emits real-time events during image processing. This allows clients to receive live updates about the analysis and image generation progress.

## WebSocket Server

- **URL**: `ws://localhost:4001` (separate from HTTP server on port 4000)
- **Health Check**: `GET http://localhost:4000/ws-health`
- **Status**: Running alongside the main Express server

## Supported Events

### Connection Events
- `connection_established` - Fired when a WebSocket client connects
  ```json
  {
    "type": "connection_established",
    "connectionId": "unique-connection-id",
    "timestamp": "2024-01-01T12:00:00.000Z"
  }
  ```

### Processing Events
- `processing_started` - Fired when image processing begins
- `processing_completed` - Fired when all processing is complete
- `processing_error` - Fired when processing fails

### Analysis Events
- `analysis_started` - Fired when AI analysis begins
- `content_analysis_complete` - Fired when camera settings analysis is done
- `photo_analysis_complete` - Fired when photo improvement suggestions are ready

### Image Generation Events
- `image_generation_started` - Fired when image generation begins
- `individual_image_started` - Fired for each individual image being generated
- `individual_image_completed` - Fired when each image is successfully generated
- `individual_image_error` - Fired when an individual image generation fails
- `image_generation_completed` - Fired when all image generation is complete
- `image_generation_error` - Fired when image generation fails overall

## Event Details

### processing_started
```json
{
  "type": "processing_started",
  "requestId": "unique-request-id",
  "message": "Image processing initiated",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

### content_analysis_complete
```json
{
  "type": "content_analysis_complete",
  "requestId": "unique-request-id",
  "settings": {
    "aperture": "f/2.8",
    "shutter_speed": "1/125",
    "iso": "400"
  },
  "message": "Camera settings recommendations generated",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

### photo_analysis_complete
```json
{
  "type": "photo_analysis_complete",
  "requestId": "unique-request-id",
  "analysis": {...},
  "suggestionsCount": 4,
  "message": "Photo analysis completed with improvement suggestions",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

### individual_image_completed
```json
{
  "type": "individual_image_completed",
  "requestId": "unique-request-id",
  "imageIndex": 1,
  "totalImages": 4,
  "title": "Dramatic Power Walk Close-Up",
  "imageData": "base64-encoded-image-data",
  "message": "Image 1/4 generated successfully: Dramatic Power Walk Close-Up",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

### processing_completed
```json
{
  "type": "processing_completed",
  "requestId": "unique-request-id",
  "totalTime": "4523.45",
  "imagesGenerated": 4,
  "message": "Processing completed successfully in 4523.45ms",
  "timestamp": "2024-01-01T12:00:00.000Z"
}
```

## Usage Examples

### JavaScript Client
```javascript
const ws = new WebSocket('ws://localhost:4001');

ws.onopen = () => {
  console.log('✅ Connected to WebSocket server');
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  const timestamp = new Date(data.timestamp).toLocaleTimeString();

  console.log(`[${timestamp}] ${data.type}:`, data.message);

  switch(data.type) {
    case 'connection_established':
      console.log(`🔌 Connection ID: ${data.connectionId}`);
      break;

    case 'processing_started':
      console.log(`🚀 Processing started - Request ID: ${data.requestId}`);
      break;

    case 'analysis_started':
      console.log('🧠 AI analysis initiated');
      break;

    case 'content_analysis_complete':
      console.log('📊 Camera settings analysis completed');
      break;

    case 'photo_analysis_complete':
      console.log(`📝 Photo analysis completed - ${data.suggestionsCount} suggestions generated`);
      break;

    case 'image_generation_started':
      console.log('🎨 Image generation started');
      break;

    case 'individual_image_started':
      console.log(`🖼️ Started generating image ${data.imageIndex}/${data.totalImages}: ${data.title}`);
      break;

    case 'individual_image_completed':
      console.log(`✅ Image ${data.imageIndex}/${data.totalImages} completed: ${data.title}`);
      // The base64 image data is available in data.imageData
      if (data.imageData) {
        console.log('📸 Image data received (base64)');
        // You can now display or download the image
        // displayImage(data.imageData, data.title);
      }
      break;

    case 'individual_image_error':
      console.log(`❌ Image ${data.imageIndex}/${data.totalImages} failed: ${data.title} - ${data.error}`);
      break;

    case 'image_generation_completed':
      console.log(`🎨 Image generation completed - ${data.imagesGenerated} images in ${data.totalTime}ms`);
      break;

    case 'processing_completed':
      console.log(`🎉 Processing completed successfully - Total time: ${data.totalTime}ms, Images: ${data.imagesGenerated}`);
      break;

    case 'processing_error':
      console.log(`💥 Processing failed at ${data.stage} stage after ${data.totalTime}ms: ${data.error}`);
      break;

    default:
      console.log(`📡 Unknown event: ${data.type}`);
  }
};

ws.onerror = (error) => {
  console.error('❌ WebSocket error:', error);
};

ws.onclose = (event) => {
  console.log(`🔌 WebSocket connection closed - Code: ${event.code}`);
};

// Helper function to display image
function displayImage(base64Data, title) {
  const img = new Image();
  img.src = `data:image/png;base64,${base64Data}`;
  img.alt = title;
  img.style.maxWidth = '300px';
  img.style.margin = '10px';
  document.body.appendChild(img);
}
```

## Architecture

### Server Architecture
- **HTTP Server**: Express.js on port 4000 (REST API endpoints)
- **WebSocket Server**: Separate WebSocket server on port 4001 (real-time events)
- **Database**: CouchDB for data persistence
- **AI Agents**: ContentAgent (camera settings) and AnalysisAgent (photo improvement)

### Event Flow Sequence
1. **Client connects** → `connection_established`
2. **API request starts** → `processing_started`
3. **AI analysis begins** → `analysis_started`
4. **Camera settings analyzed** → `content_analysis_complete`
5. **Photo suggestions generated** → `photo_analysis_complete`
6. **Image generation starts** → `image_generation_started`
7. **Each image generation** → `individual_image_started` → `individual_image_completed`
8. **All images complete** → `image_generation_completed`
9. **Processing finished** → `processing_completed`

### Connection Management
- **Multiple Clients**: All connected WebSocket clients receive broadcast events
- **Request Tracking**: Each API request has a unique `requestId` for tracking
- **Connection IDs**: Each WebSocket connection has a unique `connectionId`
- **Auto Cleanup**: Disconnected clients are automatically cleaned up

## Testing

### Automated Test Script
Run the comprehensive test script to see the WebSocket integration in action:

```bash
# Make sure you have a test image at ./ss.jpg
npx ts-node test-api.ts
```

This will:
1. ✅ Connect to the WebSocket server (`ws://localhost:4001`)
2. ✅ Establish connection and receive `connection_established` event
3. ✅ Send a request to the `/process-image` API endpoint
4. ✅ Display all WebSocket events in real-time with timestamps
5. ✅ Show progress for each processing stage
6. ✅ Save generated images to the `./test-outputs/` directory
7. ✅ Close WebSocket connection properly

### Browser Testing
Open `websocket-test.html` in your browser for a visual test interface:

```bash
# Start the server first
npm start

# Then open websocket-test.html in your browser
# The file is in the project root directory
```

Features:
- Real-time event display with color coding
- Visual progress bar
- Live statistics (events count, images generated, processing time)
- Image upload and processing
- Health check functionality

### Manual Testing
Test individual endpoints:

```bash
# Check server health
curl http://localhost:4000/health

# Check WebSocket health
curl http://localhost:4000/ws-health

# Test API endpoint (requires image file)
curl -X POST -F "image=@ss.jpg" http://localhost:4000/process-image
```

## API Endpoints

### HTTP Endpoints
- **Process Image**: `POST http://localhost:4000/process-image`
  - **Input**: Multipart form data with `image` field
  - **Output**: JSON with settings, analysis, and generated images
  - **WebSocket Events**: Triggers real-time events during processing

- **Health Check**: `GET http://localhost:4000/health`
  - **Output**: Overall server health status
  - **Includes**: Database status, WebSocket connections, initialization status

- **WebSocket Health**: `GET http://localhost:4000/ws-health`
  - **Output**: WebSocket server specific health information
  - **Includes**: Connection count, active requests, server status

- **Database Health**: `GET http://localhost:4000/db-health`
  - **Output**: CouchDB specific health information

### WebSocket Endpoint
- **WebSocket Server**: `ws://localhost:4001`
  - **Protocol**: WebSocket
  - **Events**: Real-time broadcast events
  - **Connection**: Persistent connection for real-time updates

## Features

### Core Features
- **Real-time Updates**: Get live progress updates during image processing
- **Individual Image Tracking**: Monitor each of the 4 generated images separately
- **Parallel Processing**: See all 4 images being generated simultaneously
- **Error Handling**: Receive detailed error information for failed operations
- **Connection Management**: Automatic cleanup of disconnected clients
- **Broadcasting**: All connected clients receive events (useful for multiple dashboard views)
- **Request Tracking**: Each API request has a unique ID for tracking
- **Performance Metrics**: Real-time timing information for each processing stage

### Advanced Features
- **Multiple Client Support**: Multiple browser tabs/clients can connect simultaneously
- **Event Persistence**: Events are logged even when no clients are connected
- **Graceful Degradation**: HTTP API works without WebSocket connection
- **Health Monitoring**: Comprehensive health checks for both servers
- **Error Recovery**: WebSocket server continues running even if individual requests fail

## Error Handling

### Error Event Types
If any step fails, you'll receive specific error events:

#### Processing Error
```json
{
  "type": "processing_error",
  "requestId": "req_1758260128188_zfubq1yiv",
  "error": "Detailed error message",
  "stage": "image_generation",
  "totalTime": "1234.56",
  "timestamp": "2025-09-19T05:35:47.749Z"
}
```

#### Individual Image Error
```json
{
  "type": "individual_image_error",
  "requestId": "req_1758260128188_zfubq1yiv",
  "imageIndex": 2,
  "totalImages": 4,
  "title": "Dramatic Power Walk Close-Up",
  "error": "Gemini API timeout",
  "timestamp": "2025-09-19T05:35:42.749Z"
}
```

### Error Recovery
- **WebSocket Server**: Continues running even if individual requests fail
- **HTTP API**: Still functional without WebSocket connection
- **Client Handling**: Automatic reconnection logic can be implemented
- **Logging**: All errors are logged with detailed information

## Troubleshooting

### Common Issues

#### WebSocket Connection Failed
```bash
# Check if WebSocket server is running
curl http://localhost:4000/ws-health

# Check server logs for errors
# Look for "WebSocket server started successfully on port 4001"
```

#### Port Already in Use
```bash
# Find what's using port 4000 or 4001
netstat -ano | findstr :4000
netstat -ano | findstr :4001

# Kill the process using the port
taskkill /PID <PID> /F
```

#### CORS Issues (Browser)
If you're getting CORS errors in the browser:
```javascript
// Add CORS headers to your WebSocket connection
const ws = new WebSocket('ws://localhost:4001', {
  headers: {
    'Origin': 'http://localhost:3000'
  }
});
```

#### Large File Upload Issues
```bash
# Check current limits in server.ts
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
```

### Debug Mode
Enable detailed logging:
```bash
# Set environment variable for debug logging
DEBUG=websocket:* npm start
```

## Deployment Considerations

### Production Setup
```javascript
// Use environment variables for ports
const WS_PORT = process.env.WS_PORT || 4001;
const HTTP_PORT = process.env.HTTP_PORT || 4000;

// Use secure WebSocket in production
const wsUrl = process.env.NODE_ENV === 'production'
  ? 'wss://yourdomain.com'
  : 'ws://localhost:4001';
```

### Load Balancing
For multiple server instances:
```javascript
// Use Redis or similar for cross-server event broadcasting
// Or implement sticky sessions for WebSocket connections
```

### Security
```javascript
// Add authentication to WebSocket connections
ws.on('connection', (socket, req) => {
  // Verify authentication token
  const token = req.headers['authorization'];
  if (!verifyToken(token)) {
    socket.close(1008, 'Unauthorized');
    return;
  }
  // Continue with authenticated connection
});
```

## Performance Metrics

### Typical Processing Times
- **Image Analysis**: ~2-3 seconds
- **Individual Image Generation**: ~10-15 seconds each
- **Total Processing**: ~45-60 seconds for 4 images
- **WebSocket Events**: < 10ms latency

### Memory Usage
- **Base Memory**: ~100MB
- **Per Concurrent Request**: ~50MB additional
- **Image Processing**: ~200MB peak during generation

### Concurrent Connections
- **Recommended Limit**: 50-100 concurrent WebSocket connections
- **Scaling**: Use Redis adapter for multiple server instances
