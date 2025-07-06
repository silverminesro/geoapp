func (h *AdminHandler) CreateEventZone(c *gin.Context) {
	var req CreateEventZoneRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	zone := common.Zone{
		BaseModel:    common.BaseModel{ID: uuid.New()},
		Name:         req.Name,
		Description:  req.Description,
		Location:     req.Location,
		RadiusMeters: req.RadiusMeters,
		TierRequired: req.TierRequired,
		ZoneType:     "event",
		Properties: common.JSONB{
			"event_type": req.EventType,
			"created_by": "admin",
			"permanent":  req.Permanent,
		},
		IsActive: true,
	}

	h.db.Create(&zone)

	// Spawn event artefakty
	for _, artifact := range req.EventArtifacts {
		h.spawnEventArtifact(zone.ID, artifact)
	}

	c.JSON(201, gin.H{
		"message": "Event zone created successfully",
		"zone":    zone,
	})
}