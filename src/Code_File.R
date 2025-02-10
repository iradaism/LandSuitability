library("sf")
library("sp")
library("raster")


AOI <- st_read("Muhu.shp")
Soil.database <- st_read("soil_database.shp")
Urban.area <- shapefile("urban.shp")
Water.body <- shapefile("water_bodies.shp")
Wetland <- shapefile("wetlands.shp")

DEM <- raster("dem.tif")
TWI <- raster("twi.tif")

plot(DEM, main = "Digital elevation model of the \n Muhu island, Estonia")


# Create buffer 

water.buffer <- buffer(Water.body, width=100, dissolve=TRUE)
urban.buffer <- buffer(Urban.area, width=100, dissolve=TRUE)
wetland.buffer <- buffer(Wetland, width=150, dissolve=TRUE)

plot(water.buffer)
plot(urban.buffer)
plot(wetland.buffer)

# Vector <-> raster

empty.raster <- raster() 

empty.raster <- raster(ncol=880, nrow=902, 
                       xmn=445750, xmx=467750, 
                       ymn=6482825, ymx=6505375)


crs(DEM)

projection(empty.raster) <- "+proj=lcc +lat_0=57.5175539305556 +lon_0=24 +lat_1=59.3333333333333
+lat_2=58 +x_0=500000 +y_0=6375000 +ellps=GRS80 +units=m +no_defs"

compareCRS(DEM, empty.raster)

water.raster <- rasterize(water.buffer, empty.raster, background= 0)
urban.raster <- rasterize(urban.buffer, empty.raster, background= 0)
wetland.raster <- rasterize(wetland.buffer, empty.raster, background= 0)

plot(wetland.raster)
plot(urban.raster)
plot(water.raster)

# Restriction raster 

restriction <- water.raster  | urban.raster  | wetland.raster
plot(restriction)


# Reclassify 

Soil.database$Type <- ifelse(Soil.database$upd_siffer %in% c( "K", "Kr", "Krg"), 3,
                             ifelse(Soil.database$upd_siffer %in% c( " Gh1", "Gh2", "Kg", "Khg"), 2, 1))

Soil.database$Texture <- ifelse(Soil.database$LXTYPE1 %in% c( "SL", "LS"), 3,
                                ifelse(Soil.database$LXTYPE1 %in% c( "L", "S"), 2, 1)) 


# Rasterize soil database

soil.type <- rasterize(Soil.database, empty.raster, "Type")

soil.texture <- rasterize(Soil.database, empty.raster, "Texture")

plot(soil.texture)
plot(soil.type)



# Slope

Slope <- terrain(DEM, opt="slope", unit="degrees")

plot(Slope)

# Histogram 

hist(Slope,
     main = "Distribution of slope values",
     xlab = "slope (degrees)", ylab = "Frequency",
     col = "springgreen")


hist(Slope,
     breaks= 100,
     main = "Distribution of slope values",
     xlab = "slope (degrees)", ylab = "Frequency",
     col = "springgreen")


summary(Slope)


reclass.matrix <- c(0, 0.7, 3,
                    0.7, 0.9, 2,
                    0.9, Inf, 1)


reclass.matrix.reshape <- matrix(reclass.matrix,
                                 ncol = 3,
                                 byrow = TRUE)


reclass.matrix.reshape

slope.reclassified <- reclassify(Slope, reclass.matrix.reshape)


plot(slope.reclassified)

summary(slope.reclassified)

barplot(slope.reclassified)

slope.reclassified[slope.reclassified == 0] <- 1


summary(TWI)

reclass.matrix2 <- c(5, 10, 3,
                     10, Inf, 2,
                     0, 5, 1)

reclass.matrix2.reshape <- matrix(reclass.matrix2,
                                  ncol = 3,
                                  byrow = TRUE)

twi.reclassified <- reclassify(TWI, reclass.matrix2.reshape)
barplot(twi.reclassified)


twi.reclassified[twi.reclassified == 0] <- 1


# Weighted overlay



weighted.overlay <- (0.595* soil.type) + (0.265* soil.texture) + (0.070* slope.reclassified) + (0.070* twi.reclassified)

plot(weighted.overlay)

reclass.matrix3 <- c(2.3, 3, 3,
                     1.6, 2.3, 2,
                     0, 1.6, 1)

reclass.matrix3.reshape <- matrix(reclass.matrix3,
                                  ncol = 3,
                                  byrow = TRUE)

overlay.reclass <- reclassify(weighted.overlay, reclass.matrix3.reshape)

plot(overlay.reclass)


restriction.invert <- (restriction-1) * (-1)

plot(restriction.invert)

suitable.areas <- restriction.invert*overlay.reclass

barplot(suitable.areas)
plot(suitable.areas)
barplot(suitable.areas)

#suitable.areas[suitable.areas == 0] <- 1


mycol <- c( "blue", "green", "red")

plot(suitable.areas, 
     main="Suitable areas for alvar grassland restoration", 
     axes=FALSE)

writeRaster(suitable.areas, "suitable_areas.tif")

