# SnatchShot Cloud Database API Documentation

## 📋 Overview

SnatchShot Cloud provides a comprehensive REST API for managing users, pictures, and AI-generated images. The API is built with Node.js, Express, and CouchDB, providing scalable document-based storage with attachment support.

### 🔧 Technical Stack
- **Backend**: Node.js with Express.js
- **Database**: CouchDB (NoSQL document database)
- **Authentication**: Password-based with PBKDF2 hashing
- **File Storage**: CouchDB attachments for images
- **Image Processing**: Sharp library for thumbnails and metadata
- **Logging**: Custom structured logging system

---

## 🌐 Base URL
```
http://localhost:4000/api
```

## 📊 API Endpoints

### Health Check Endpoints

#### 1. Server Health Check
**GET** `/health`

Check server and database connectivity status.

**Response:**
```json
{
  "status": "ok",
  "database": "connected",
  "initialized": true,
  "timestamp": "2025-09-17T14:01:04.236Z"
}
```

#### 2. Database Health Check
**GET** `/db-health`

Check database health and document type status.

**Response:**
```json
{
  "couchdb": "healthy",
  "database": "snatchshot",
  "document_types": {
    "users": true,
    "pictures": true,
    "generated_pictures": true
  },
  "timestamp": "2025-09-17T14:01:04.585Z"
}
```

---

## 👤 User Management APIs

### User Registration
**POST** `/users/register`

Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123",
  "username": "unique_username",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Required Fields:**
- `email` (string): Valid email address
- `password` (string): Minimum 8 characters

**Optional Fields:**
- `username` (string): Unique username
- `first_name` (string): User's first name
- `last_name` (string): User's last name

**Success Response (201):**
```json
{
  "user": {
    "user_id": "usr_abc123def456",
    "email": "user@example.com",
    "username": "unique_username",
    "first_name": "John",
    "last_name": "Doe",
    "email_verified": false,
    "is_active": true,
    "price_plan": {
      "id": "free",
      "name": "Free",
      "description": "Basic features with limited usage",
      "price": 0,
      "currency": "USD",
      "billing_cycle": "monthly",
      "features": ["Basic image processing", "Limited storage"],
      "max_images_per_month": 50,
      "max_storage_gb": 1,
      "priority_support": false
    },
    "created_at": "2025-09-17T14:01:04.236Z",
    "updated_at": "2025-09-17T14:01:04.236Z"
  }
}
```

### User Login
**POST** `/users/login`

Authenticate user credentials.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Required Fields:**
- `email` (string): User's email address
- `password` (string): User's password

**Success Response (200):**
```json
{
  "user": {
    "user_id": "usr_abc123def456",
    "email": "user@example.com",
    "username": "unique_username",
    "first_name": "John",
    "last_name": "Doe",
    "email_verified": false,
    "is_active": true,
    "price_plan": {
      "id": "free",
      "name": "Free",
      "description": "Basic features with limited usage",
      "price": 0,
      "currency": "USD",
      "billing_cycle": "monthly",
      "features": ["Basic image processing", "Limited storage"],
      "max_images_per_month": 50,
      "max_storage_gb": 1,
      "priority_support": false
    }
  },
  "token": "jwt_token_here"
}
```

**Error Response (401):**
```json
{
  "error": "Invalid email or password"
}
```

### Get User Profile
**GET** `/users/profile/{userId}`

Retrieve user profile information.

**Path Parameters:**
- `userId` (string): User's unique ID (e.g., `usr_abc123def456`)

**Success Response (200):**
```json
{
  "user": {
    "user_id": "usr_abc123def456",
    "email": "user@example.com",
    "username": "unique_username",
    "first_name": "John",
    "last_name": "Doe",
    "email_verified": false,
    "is_active": true,
    "price_plan": {
      "id": "free",
      "name": "Free",
      "description": "Basic features with limited usage",
      "price": 0,
      "currency": "USD",
      "billing_cycle": "monthly",
      "features": ["Basic image processing", "Limited storage"],
      "max_images_per_month": 50,
      "max_storage_gb": 1,
      "priority_support": false
    },
    "login_count": 5,
    "last_login": "2025-09-17T14:01:04.236Z",
    "created_at": "2025-09-17T14:01:04.236Z",
    "updated_at": "2025-09-17T14:01:04.236Z"
  }
}
```

### Update User Profile
**PUT** `/users/profile/{userId}`

Update user profile information.

**Path Parameters:**
- `userId` (string): User's unique ID

**Request Body:**
```json
{
  "first_name": "Updated First Name",
  "last_name": "Updated Last Name",
  "username": "new_username"
}
```

**Allowed Update Fields:**
- `first_name` (string)
- `last_name` (string)
- `username` (string)

**Success Response (200):**
```json
{
  "user": {
    "user_id": "usr_abc123def456",
    "email": "user@example.com",
    "username": "new_username",
    "first_name": "Updated First Name",
    "last_name": "Updated Last Name",
    "updated_at": "2025-09-17T14:01:04.236Z"
  }
}
```

---

## 📸 Picture Management APIs

### Upload Picture
**POST** `/pictures/upload`

Upload an image file with metadata.

**Content-Type:** `multipart/form-data`

**Form Data:**
- `image` (file): Image file (JPEG, PNG, etc.)
- `user_id` (string): User's unique ID
- `tags` (string): JSON array of tags `["tag1", "tag2"]`
- `categories` (string): JSON array of categories `["category1"]`
- `device_info` (string): JSON object with device information

**Example Form Data:**
```
image: [ss.jpg file]
user_id: usr_abc123def456
tags: ["screenshot", "test"]
categories: ["demo"]
device_info: {"platform": "ios", "app_version": "1.0.0", "device_model": "iPhone12,1"}
```

**Success Response (201):**
```json
{
  "picture": {
    "_id": "1651fac75732e58470b5eb185534adc9",
    "type": "picture",
    "user_id": "usr_abc123def456",
    "picture_id": "pic_xyz789abc",
    "filename": "pic_xyz789abc_ss.jpg",
    "original_filename": "ss.jpg",
    "mime_type": "image/jpeg",
    "size_bytes": 360270,
    "width": 2041,
    "height": 3068,
    "orientation": "portrait",
    "color_space": "srgb",
    "has_alpha": false,
    "device_info": {
      "platform": "ios",
      "app_version": "1.0.0",
      "device_model": "iPhone12,1",
      "os_version": "15.0"
    },
    "processing_status": "processed",
    "tags": ["screenshot", "test"],
    "categories": ["demo"],
    "view_count": 0,
    "like_count": 0,
    "share_count": 0,
    "created_at": "2025-09-17T14:02:23.997Z",
    "updated_at": "2025-09-17T14:02:23.997Z"
  },
  "download_url": "/api/pictures/1651fac75732e58470b5eb185534adc9/download"
}
```

### Get Picture by ID
**GET** `/pictures/{pictureId}`

Retrieve picture metadata by ID.

**Path Parameters:**
- `pictureId` (string): Picture's document ID

**Success Response (200):**
```json
{
  "picture": {
    "_id": "1651fac75732e58470b5eb185534adc9",
    "type": "picture",
    "user_id": "usr_abc123def456",
    "picture_id": "pic_xyz789abc",
    "filename": "pic_xyz789abc_ss.jpg",
    "original_filename": "ss.jpg",
    "mime_type": "image/jpeg",
    "size_bytes": 360270,
    "width": 2041,
    "height": 3068,
    "orientation": "portrait",
    "processing_status": "processed",
    "tags": ["screenshot", "test"],
    "categories": ["demo"],
    "view_count": 0,
    "created_at": "2025-09-17T14:02:23.997Z",
    "updated_at": "2025-09-17T14:02:23.997Z"
  }
}
```

### Get User Pictures
**GET** `/pictures/user/{userId}`

Retrieve all pictures for a specific user with pagination.

**Path Parameters:**
- `userId` (string): User's unique ID

**Query Parameters:**
- `limit` (number, optional): Number of results per page (default: 10)
- `skip` (number, optional): Number of results to skip (default: 0)

**Example:** `/api/pictures/user/usr_abc123def456?limit=20&skip=0`

**Success Response (200):**
```json
{
  "data": [
    {
      "_id": "1651fac75732e58470b5eb185534adc9",
      "type": "picture",
      "user_id": "usr_abc123def456",
      "picture_id": "pic_xyz789abc",
      "filename": "pic_xyz789abc_ss.jpg",
      "original_filename": "ss.jpg",
      "mime_type": "image/jpeg",
      "size_bytes": 360270,
      "width": 2041,
      "height": 3068,
      "orientation": "portrait",
      "processing_status": "processed",
      "tags": ["screenshot", "test"],
      "created_at": "2025-09-17T14:02:23.997Z"
    }
  ],
  "total": 1,
  "limit": 20,
  "skip": 0
}
```

### Download Picture
**GET** `/pictures/{pictureId}/download`

Download the original uploaded image file.

**Path Parameters:**
- `pictureId` (string): Picture's document ID

**Query Parameters:**
- `userId` (string, required): User's unique ID for authorization

**Example:** `/api/pictures/1651fac75732e58470b5eb185534adc9/download?userId=usr_abc123def456`

**Success Response (200):**
- Content-Type: `image/jpeg` (or appropriate MIME type)
- Body: Binary image data

### Download Picture Thumbnail
**GET** `/pictures/{pictureId}/thumbnail`

Download the generated thumbnail image.

**Path Parameters:**
- `pictureId` (string): Picture's document ID

**Query Parameters:**
- `userId` (string, required): User's unique ID for authorization

**Example:** `/api/pictures/1651fac75732e58470b5eb185534adc9/thumbnail?userId=usr_abc123def456`

**Success Response (200):**
- Content-Type: `image/jpeg`
- Body: Binary thumbnail image data (300x300 max, optimized)

### Search Pictures by Tags
**GET** `/pictures/search/tags`

Search pictures by tags with pagination.

**Query Parameters:**
- `user_id` (string, required): User's unique ID
- `tags` (string): JSON array of tags to search for
- `limit` (number, optional): Number of results per page (default: 10)
- `skip` (number, optional): Number of results to skip (default: 0)

**Example:** `/api/pictures/search/tags?user_id=usr_abc123def456&tags=["test"]&limit=10`

**Success Response (200):**
```json
{
  "data": [
    {
      "_id": "1651fac75732e58470b5eb185534adc9",
      "type": "picture",
      "user_id": "usr_abc123def456",
      "picture_id": "pic_xyz789abc",
      "filename": "pic_xyz789abc_ss.jpg",
      "tags": ["screenshot", "test"],
      "created_at": "2025-09-17T14:02:23.997Z"
    }
  ],
  "total": 1,
  "limit": 10,
  "skip": 0
}
```

### Update Picture Metadata
**PUT** `/pictures/{pictureId}`

Update picture tags and categories.

**Path Parameters:**
- `pictureId` (string): Picture's document ID

**Request Body:**
```json
{
  "tags": ["new_tag", "another_tag"],
  "categories": ["new_category"]
}
```

**Success Response (200):**
```json
{
  "picture": {
    "_id": "1651fac75732e58470b5eb185534adc9",
    "type": "picture",
    "user_id": "usr_abc123def456",
    "tags": ["new_tag", "another_tag"],
    "categories": ["new_category"],
    "updated_at": "2025-09-17T14:02:23.997Z"
  }
}
```

---

## 🎨 Generated Picture APIs

### Start Generation
**POST** `/generated-pictures/generate/start`

Create a generation placeholder for AI image processing.

**Request Body:**
```json
{
  "user_id": "usr_abc123def456",
  "parent_picture_id": "1651fac75732e58470b5eb185534adc9",
  "generation_settings": {
    "style": "realistic",
    "creativity_level": 75,
    "color_enhancement": true,
    "aspect_ratio": "1:1"
  }
}
```

**Success Response (201):**
```json
{
  "placeholder_id": "1651fac75732e58470b5eb185534b596",
  "message": "Generation placeholder created successfully"
}
```

### Upload Generated Picture
**POST** `/generated-pictures/upload`

Upload an AI-generated image.

**Content-Type:** `multipart/form-data`

**Form Data:**
- `image` (file): Generated image file
- `user_id` (string): User's unique ID
- `parent_picture_id` (string): ID of the original picture
- `generation_settings` (string): JSON object with generation settings

**Success Response (201):**
```json
{
  "generated_picture": {
    "_id": "1651fac75732e58470b5eb185534966d",
    "type": "generated_picture",
    "user_id": "usr_abc123def456",
    "generated_picture_id": "gen_abc123def456",
    "parent_picture_id": "1651fac75732e58470b5eb185534adc9",
    "filename": "gen_abc123def456_generated-image.png",
    "original_filename": "generated-image.png",
    "mime_type": "image/png",
    "size_bytes": 245760,
    "width": 1024,
    "height": 1024,
    "orientation": "square",
    "generation_settings": {
      "style": "realistic",
      "creativity_level": 80,
      "color_enhancement": true,
      "aspect_ratio": "1:1"
    },
    "generation_status": "completed",
    "rating": null,
    "feedback": null,
    "created_at": "2025-09-17T14:02:23.997Z"
  },
  "download_url": "/api/generated-pictures/1651fac75732e58470b5eb185534966d/download"
}
```

### Get Generated Picture by ID
**GET** `/generated-pictures/{generatedPictureId}`

Retrieve generated picture metadata.

**Path Parameters:**
- `generatedPictureId` (string): Generated picture's document ID

**Success Response (200):**
```json
{
  "generated_picture": {
    "_id": "1651fac75732e58470b5eb185534966d",
    "type": "generated_picture",
    "user_id": "usr_abc123def456",
    "generated_picture_id": "gen_abc123def456",
    "parent_picture_id": "1651fac75732e58470b5eb185534adc9",
    "filename": "gen_abc123def456_generated-image.png",
    "generation_settings": {
      "style": "realistic",
      "creativity_level": 80,
      "color_enhancement": true,
      "aspect_ratio": "1:1"
    },
    "generation_status": "completed",
    "rating": 4,
    "feedback": "Great generation quality!",
    "created_at": "2025-09-17T14:02:23.997Z"
  }
}
```

### Get Generated Pictures by User
**GET** `/generated-pictures/user/{userId}`

Retrieve all generated pictures for a user.

**Path Parameters:**
- `userId` (string): User's unique ID

**Query Parameters:**
- `limit` (number, optional): Number of results per page (default: 10)
- `skip` (number, optional): Number of results to skip (default: 0)

**Success Response (200):**
```json
{
  "data": [
    {
      "_id": "1651fac75732e58470b5eb185534966d",
      "type": "generated_picture",
      "user_id": "usr_abc123def456",
      "parent_picture_id": "1651fac75732e58470b5eb185534adc9",
      "filename": "gen_abc123def456_generated-image.png",
      "generation_status": "completed",
      "rating": 4,
      "created_at": "2025-09-17T14:02:23.997Z"
    }
  ],
  "total": 2,
  "limit": 10,
  "skip": 0
}
```

### Get Generated Pictures by Parent
**GET** `/generated-pictures/parent/{parentPictureId}`

Retrieve all generated pictures for a specific parent picture.

**Path Parameters:**
- `parentPictureId` (string): Parent picture's document ID

**Query Parameters:**
- `limit` (number, optional): Number of results per page (default: 10)
- `skip` (number, optional): Number of results to skip (default: 0)

**Success Response (200):**
```json
{
  "data": [
    {
      "_id": "1651fac75732e58470b5eb185534966d",
      "type": "generated_picture",
      "user_id": "usr_abc123def456",
      "parent_picture_id": "1651fac75732e58470b5eb185534adc9",
      "filename": "gen_abc123def456_generated-image.png",
      "generation_status": "completed"
    }
  ],
  "total": 2,
  "limit": 10,
  "skip": 0
}
```

### Download Generated Picture
**GET** `/generated-pictures/{generatedPictureId}/download`

Download the AI-generated image file.

**Path Parameters:**
- `generatedPictureId` (string): Generated picture's document ID

**Query Parameters:**
- `userId` (string, required): User's unique ID for authorization

**Success Response (200):**
- Content-Type: `image/png` (or appropriate MIME type)
- Body: Binary generated image data

### Download Generated Picture Thumbnail
**GET** `/generated-pictures/{generatedPictureId}/thumbnail`

Download the thumbnail of the generated image.

**Path Parameters:**
- `generatedPictureId` (string): Generated picture's document ID

**Query Parameters:**
- `userId` (string, required): User's unique ID for authorization

**Success Response (200):**
- Content-Type: `image/jpeg`
- Body: Binary thumbnail image data

### Rate Generated Picture
**POST** `/generated-pictures/{generatedPictureId}/rate`

Submit a rating and feedback for a generated picture.

**Path Parameters:**
- `generatedPictureId` (string): Generated picture's document ID

**Request Body:**
```json
{
  "rating": 4,
  "feedback": "Great generation quality!",
  "userId": "usr_abc123def456"
}
```

**Success Response (200):**
```json
{
  "message": "Rating submitted successfully",
  "generated_picture": {
    "_id": "1651fac75732e58470b5eb185534966d",
    "rating": 4,
    "feedback": "Great generation quality!",
    "updated_at": "2025-09-17T14:02:23.997Z"
  }
}
```

### Get Generation Statistics
**GET** `/generated-pictures/stats/{userId}`

Retrieve generation statistics for a user.

**Path Parameters:**
- `userId` (string): User's unique ID

**Success Response (200):**
```json
{
  "user_id": "usr_abc123def456",
  "total_generations": 5,
  "completed_generations": 4,
  "failed_generations": 1,
  "average_rating": 4.2,
  "total_ratings": 4,
  "generation_success_rate": 80,
  "most_used_style": "realistic",
  "last_generation": "2025-09-17T14:02:23.997Z"
}
```

---

## 📋 Error Responses

### Common Error Format
```json
{
  "error": "Error message description"
}
```

### HTTP Status Codes

| Status Code | Description |
|-------------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (missing/invalid parameters) |
| 401 | Unauthorized (invalid credentials) |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found (resource doesn't exist) |
| 409 | Conflict (document update conflict) |
| 500 | Internal Server Error |

### Common Error Messages

- `"Email and password are required"`
- `"Invalid email or password"`
- `"User with this email already exists"`
- `"No image file provided"`
- `"User ID is required"`
- `"Failed to download picture"`
- `"Thumbnail not found"`
- `"Document update conflict"`

---

## 🔐 Authentication & Authorization

### Authentication Method
- **Type**: Password-based authentication
- **Hashing**: PBKDF2 with 1000 iterations, 64-byte key, SHA-512
- **Salt**: 16-byte random salt per user

### Authorization
- User-specific resources require `userId` parameter
- Picture operations require matching user ownership
- Generated pictures require parent picture ownership

### Security Features
- Password hashing with PBKDF2
- Email normalization (lowercase storage)
- Input validation and sanitization
- Rate limiting (recommended for production)

---

## 📊 Database Schema

### Document Types

#### User Document
```json
{
  "_id": "usr_abc123def456",
  "type": "user",
  "user_id": "usr_abc123def456",
  "email": "user@example.com",
  "username": "unique_username",
  "first_name": "John",
  "last_name": "Doe",
  "password_hash": "pbkdf2_hash...",
  "salt": "random_salt...",
  "email_verified": false,
  "is_active": true,
  "price_plan": {...},
  "login_count": 5,
  "last_login": "2025-09-17T14:01:04.236Z",
  "created_at": "2025-09-17T14:01:04.236Z",
  "updated_at": "2025-09-17T14:01:04.236Z"
}
```

#### Picture Document
```json
{
  "_id": "1651fac75732e58470b5eb185534adc9",
  "type": "picture",
  "user_id": "usr_abc123def456",
  "picture_id": "pic_xyz789abc",
  "filename": "pic_xyz789abc_ss.jpg",
  "original_filename": "ss.jpg",
  "mime_type": "image/jpeg",
  "size_bytes": 360270,
  "width": 2041,
  "height": 3068,
  "orientation": "portrait",
  "color_space": "srgb",
  "has_alpha": false,
  "device_info": {...},
  "processing_status": "processed",
  "tags": ["screenshot", "test"],
  "categories": ["demo"],
  "view_count": 0,
  "like_count": 0,
  "share_count": 0,
  "created_at": "2025-09-17T14:02:23.997Z",
  "updated_at": "2025-09-17T14:02:23.997Z"
}
```

#### Generated Picture Document
```json
{
  "_id": "1651fac75732e58470b5eb185534966d",
  "type": "generated_picture",
  "user_id": "usr_abc123def456",
  "generated_picture_id": "gen_abc123def456",
  "parent_picture_id": "1651fac75732e58470b5eb185534adc9",
  "filename": "gen_abc123def456_generated-image.png",
  "original_filename": "generated-image.png",
  "mime_type": "image/png",
  "size_bytes": 245760,
  "width": 1024,
  "height": 1024,
  "orientation": "square",
  "generation_settings": {...},
  "generation_status": "completed",
  "rating": 4,
  "feedback": "Great generation quality!",
  "created_at": "2025-09-17T14:02:23.997Z",
  "updated_at": "2025-09-17T14:02:23.997Z"
}
```

---

## 🧪 Testing

### Test Scripts Available
```bash
# Clean database
node --import tsx cleanup-db.ts

# Test individual components
node --import tsx test-health.ts      # Health checks
node --import tsx test-user.ts        # User management
node --import tsx test-picture.ts     # Picture management
node --import tsx test-generated.ts   # Generated pictures
node --import tsx test-ss-upload.ts   # SS.jpg upload test

# Run all tests
node --import tsx run-all-tests.ts

# Run comprehensive test
npm run test:couchdb
```

### Test Results Summary
- ✅ **Health APIs**: 100% working
- ✅ **User APIs**: 100% working (registration, login, profile)
- ✅ **Picture APIs**: Mostly working (upload, retrieval, search)
- ⚠️ **Download APIs**: Issues with attachment retrieval
- ✅ **Generated Picture APIs**: Mostly working

---

## 🚀 Production Considerations

### Performance Optimizations
- Implement caching for frequently accessed images
- Add rate limiting for API endpoints
- Use CDN for image delivery
- Optimize image processing workflows

### Security Enhancements
- Implement JWT token authentication
- Add request validation middleware
- Enable CORS configuration
- Add API key authentication for mobile apps

### Monitoring & Logging
- Implement structured logging
- Add performance monitoring
- Set up error tracking
- Monitor database usage and performance

### Scalability
- Implement database sharding
- Add load balancing
- Use connection pooling
- Implement background job processing for image operations

---

## 📞 Support & Documentation

- **API Documentation**: `API_DOCUMENTATION.md`
- **Testing Guide**: `TESTING_README.md`
- **Database Schema**: `src/types/database.ts`
- **Test Scripts**: `test-*.ts` files

For additional support, check the server logs or test script outputs for detailed error messages.
