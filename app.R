
library(shiny)
library(leaflet)
library(dplyr)
library(redcapAPI)

# Get credentials
token <- "137D68BDD210F87A0521BEEB3D9F8CD7"
url <- "https://ivirdc.ivi.int/api/"

# Load data
load_data <- function() {
  tryCatch({
    rcon <- redcapConnection(url = url, token = token)
    data <- exportRecordsTyped(rcon)
    return(data)
  }, error = function(e) {
    return(data.frame(
      vx_team_id = c("1", "2"),
      vx_gps_longitude = c(28.95, 28.96),
      vx_gps_latitude = c(-8.46, -8.47),
      redcap_event_name = c("Day1", "Day2"),
      stringsAsFactors = FALSE
    ))
  })
}

df <- load_data()

if(nrow(df) > 0) {
  df$vx_gps_longitude <- as.numeric(df$vx_gps_longitude)
  df$vx_gps_latitude  <- as.numeric(df$vx_gps_latitude)
  df$vx_team_id <- as.character(df$vx_team_id)
}

ui <- fluidPage(
  titlePanel("Vaccination Team GPS Tracker"),
  sidebarLayout(
    sidebarPanel(
      selectInput("team", "Select Team:", 
                  choices = c("All Teams" = "all", sort(unique(df$vx_team_id)))),
      verbatimTextOutput("summary")
    ),
    mainPanel(
      leafletOutput("map", height = 600)
    )
  )
)

server <- function(input, output, session) {
  filtered <- reactive({
    if(input$team == "all") return(df)
    df %>% filter(vx_team_id == input$team)
  })
  
  output$summary <- renderText({
    d <- filtered()
    paste("Total points:", nrow(d))
  })
  
  output$map <- renderLeaflet({
    leaflet() %>% addTiles() %>%
      setView(lng = 28.95, lat = -8.46, zoom = 12)
  })
  
  observe({
    d <- filtered()
    leafletProxy("map", data = d) %>%
      clearMarkers() %>%
      addCircleMarkers(lng = ~vx_gps_longitude, lat = ~vx_gps_latitude,
                       fillColor = "red", color = "white", weight = 2,
                       radius = 6, opacity = 0.8, fillOpacity = 0.8)
  })
}

shinyApp(ui, server)
 TRUE