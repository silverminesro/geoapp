package auth

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func setupTestDB(t *testing.T) *gorm.DB {
	err := godotenv.Load(".env")
	if err != nil {
		t.Log("Warning: .env file not loaded, using system env")
	}

	dsn := fmt.Sprintf(
		"host=%s user=%s password=%s dbname=%s port=%s sslmode=%s TimeZone=%s",
		os.Getenv("DB_HOST"),
		os.Getenv("DB_USER"),
		os.Getenv("DB_PASSWORD"),
		os.Getenv("DB_NAME"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_SSLMODE"),
		os.Getenv("DB_TIMEZONE"),
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("failed to connect to test database: %v", err)
	}
	return db
}

// Test only DB connection
func TestDB_Connection(t *testing.T) {
	db := setupTestDB(t)
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("failed to get generic DB: %v", err)
	}
	if err := sqlDB.Ping(); err != nil {
		t.Fatalf("DB ping failed: %v", err)
	}
}

// Test successful registration
func TestRegister_Success(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	db := setupTestDB(t)
	handler := NewHandler(db, nil)
	router.POST("/register", handler.Register)

	unique := fmt.Sprintf("tester%d", time.Now().UnixNano())
	body := []byte(fmt.Sprintf(`{"username": "%s", "email": "%s@example.com", "password": "superpassword123"}`, unique, unique))
	req, _ := http.NewRequest("POST", "/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status 201 Created, got %d", w.Code)
		t.Logf("Body: %s", w.Body.String())
	}

	var resp map[string]interface{}
	_ = json.Unmarshal(w.Body.Bytes(), &resp)
	if resp["token"] == nil || resp["user"] == nil {
		t.Error("expected token and user in response")
	}
}

// Test duplicate user registration (conflict)
func TestRegister_Conflict(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	db := setupTestDB(t)
	handler := NewHandler(db, nil)
	router.POST("/register", handler.Register)

	// First registration
	unique := fmt.Sprintf("duptest%d", time.Now().UnixNano())
	body := []byte(fmt.Sprintf(`{"username": "%s", "email": "%s@example.com", "password": "superpassword123"}`, unique, unique))
	req, _ := http.NewRequest("POST", "/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("initial register failed, code %d, body %s", w.Code, w.Body.String())
	}

	// Second registration with same username/email
	req2, _ := http.NewRequest("POST", "/register", bytes.NewBuffer(body))
	req2.Header.Set("Content-Type", "application/json")
	w2 := httptest.NewRecorder()
	router.ServeHTTP(w2, req2)

	if w2.Code != http.StatusConflict {
		t.Errorf("expected status 409 Conflict, got %d", w2.Code)
		t.Logf("Body: %s", w2.Body.String())
	}
}

// Test invalid registration payload
func TestRegister_InvalidRequest(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	db := setupTestDB(t)
	handler := NewHandler(db, nil)
	router.POST("/register", handler.Register)

	// Missing email
	body := []byte(`{"username": "baduser", "password": "123"}`)
	req, _ := http.NewRequest("POST", "/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status 400 Bad Request, got %d", w.Code)
		t.Logf("Body: %s", w.Body.String())
	}
}
