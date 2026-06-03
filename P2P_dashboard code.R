
# List of required packages
packages <- c("tidyverse", "shiny", "shinydashboard", "plotly", "lubridate", "scales", "DT")

# Install missing packages
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}

# Load packages
invisible(lapply(packages, library, character.only = TRUE))
set.seed(42)
n <- 2000

vendors <- c(
  "Safaricom Ltd", "Kenya Power", "Nation Media Group",
  "Bamburi Cement", "Total Energies Kenya", "UAP Insurance",
  "KPMG Advisory", "DHL Kenya", "Tata Chemicals Magadi",
  "ARM Cement", "Equity Bank", "Kenya Airways Cargo"
)

departments <- c("Finance", "IT", "Operations", "HR", "Sales", "Procurement")

gl_accounts <- c(
  "5100-Supplies", "5200-Services", "5300-Utilities",
  "5400-Maintenance", "5500-Travel", "6100-Consulting"
)

invoice_dates <- sort(
  as.Date("2024-01-01") + sample(0:364, n, replace = TRUE)
)

processing_days <- ifelse(
  runif(n) < 0.15,
  sample(31:60, n, replace = TRUE),   # 15% late exceptions
  sample(5:25,  n, replace = TRUE)    # 85% normal
)

payment_terms <- sample(c(30, 45, 60), n,
                        replace = TRUE, prob = c(0.5, 0.3, 0.2))

invoice_amounts <- round(rlnorm(n, meanlog = 10, sdlog = 1.5), 2)

df <- tibble(
  invoice_id      = paste0("INV-", str_pad(1:n, 5, pad = "0")),
  vendor          = sample(vendors,      n, replace = TRUE),
  department      = sample(departments,  n, replace = TRUE),
  gl_account      = sample(gl_accounts,  n, replace = TRUE),
  invoice_date    = invoice_dates,
  invoice_amount  = invoice_amounts,
  payment_terms   = payment_terms,
  processing_days = processing_days
) %>%
  mutate(
    due_date     = invoice_date + days(payment_terms),
    payment_date = invoice_date + days(processing_days),
    paid_on_time = payment_date <= due_date,
    days_overdue = pmax(as.integer(payment_date - due_date), 0),
    aging_bucket = case_when(
      days_overdue == 0  ~ "Current",
      days_overdue <= 30 ~ "1-30 days",
      days_overdue <= 60 ~ "31-60 days",
      TRUE               ~ "60+ days"
    ),
    gl_status = sample(
      c("Reconciled", "Pending", "Exception"),
      n, replace = TRUE, prob = c(0.78, 0.14, 0.08)
    ),
    has_exception = gl_status == "Exception" | days_overdue > 30,
    month         = floor_date(invoice_date, "month")
  )

write_csv(df, "p2p_invoices.csv")
cat("Generated", nrow(df), "invoice records\n")
glimpse(df)
# ── Load data ──────────────────────────────────────────────
df <- read_csv("p2p_invoices.csv", show_col_types = FALSE) %>%
  mutate(
    invoice_date = as.Date(invoice_date),
    due_date     = as.Date(due_date),
    payment_date = as.Date(payment_date),
    month        = as.Date(month),
    aging_bucket = factor(aging_bucket,
                          levels = c("Current", "1-30 days",
                                     "31-60 days", "60+ days"))
  )

# ── UI ─────────────────────────────────────────────────────
ui <- dashboardPage(
  skin = "purple",
  
  dashboardHeader(title = "P2P Analytics"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview",      tabName = "overview",  icon = icon("chart-bar")),
      menuItem("Aging & GL",    tabName = "aging",     icon = icon("clock")),
      menuItem("Invoice Detail",tabName = "detail",    icon = icon("table"))
    ),
    hr(),
    selectInput("dept_filter", "Department",
                choices  = c("All", unique(df$department)),
                selected = "All"),
    selectInput("vendor_filter", "Vendor",
                choices  = c("All", sort(unique(df$vendor))),
                selected = "All"),
    sliderInput("month_range", "Date range",
                min   = min(df$invoice_date),
                max   = max(df$invoice_date),
                value = c(min(df$invoice_date), max(df$invoice_date)),
                timeFormat = "%b %Y")
  ),
  
  dashboardBody(
    tags$head(tags$style(HTML("
      .small-box { border-radius: 8px; }
      .content-wrapper { background-color: #f8f8f8; }
    "))),
    
    tabItems(
      # ── Overview tab ──────────────────────────────────────
      tabItem(tabName = "overview",
              
              fluidRow(
                valueBoxOutput("box_total",    width = 3),
                valueBoxOutput("box_value",    width = 3),
                valueBoxOutput("box_cycle",    width = 3),
                valueBoxOutput("box_ontime",   width = 3)
              ),
              fluidRow(
                valueBoxOutput("box_exception", width = 3),
                valueBoxOutput("box_overdue",   width = 3),
                valueBoxOutput("box_pending_gl",width = 3),
                valueBoxOutput("box_avg_amount",width = 3)
              ),
              
              fluidRow(
                box(title = "Monthly invoice volume & on-time rate",
                    plotlyOutput("chart_monthly"), width = 8),
                box(title = "Invoices by department",
                    plotlyOutput("chart_dept"),   width = 4)
              ),
              
              fluidRow(
                box(title = "Avg cycle time by department",
                    plotlyOutput("chart_cycle"),  width = 6),
                box(title = "Exception rate trend",
                    plotlyOutput("chart_exception"), width = 6)
              )
      ),
      
      # ── Aging & GL tab ────────────────────────────────────
      tabItem(tabName = "aging",
              fluidRow(
                box(title = "Vendor payment aging (KES)",
                    plotlyOutput("chart_aging"),  width = 8),
                box(title = "GL reconciliation status",
                    plotlyOutput("chart_gl"),     width = 4)
              ),
              fluidRow(
                box(title = "Aging breakdown by value",
                    plotlyOutput("chart_aging_pie"), width = 6),
                box(title = "Top vendors by overdue value",
                    plotlyOutput("chart_top_overdue"), width = 6)
              )
      ),
      
      # ── Invoice detail tab ────────────────────────────────
      tabItem(tabName = "detail",
              fluidRow(
                box(title = "Invoice register",
                    DTOutput("invoice_table"), width = 12)
              )
      )
    )
  )
)
# ── Server ─────────────────────────────────────────────────
server <- function(input, output, session) {
  
  # Reactive filtered data
  dff <- reactive({
    d <- df %>%
      filter(invoice_date >= input$month_range[1],
             invoice_date <= input$month_range[2])
    if (input$dept_filter   != "All")
      d <- d %>% filter(department == input$dept_filter)
    if (input$vendor_filter != "All")
      d <- d %>% filter(vendor == input$vendor_filter)
    d
  })
  # ── KPI boxes ─────────────────────────────────────────────
  output$box_total <- renderValueBox({
    valueBox(comma(nrow(dff())), "Total invoices",
             icon = icon("file-invoice"), color = "purple")
  })
  output$box_value <- renderValueBox({
    valueBox(
      paste0("KES ", comma(round(sum(dff()$invoice_amount) / 1e6, 1)), "M"),
      "Total value", icon = icon("money-bill"), color = "blue")
  })
  output$box_cycle <- renderValueBox({
    valueBox(
      paste0(round(mean(dff()$processing_days), 1), " days"),
      "Avg cycle time", icon = icon("clock"), color = "teal")
  })
  output$box_ontime <- renderValueBox({
    pct <- round(mean(dff()$paid_on_time) * 100, 1)
    color <- if (pct >= 85) "green" else "orange"
    valueBox(paste0(pct, "%"), "On-time payments",
             icon = icon("check-circle"), color = color)
  })
  output$box_exception <- renderValueBox({
    pct <- round(mean(dff()$has_exception) * 100, 1)
    color <- if (pct <= 10) "green" else "red"
    valueBox(paste0(pct, "%"), "Exception rate",
             icon = icon("exclamation-triangle"), color = color)
  })
  output$box_overdue <- renderValueBox({
    val <- sum(dff()$days_overdue > 0)
    valueBox(comma(val), "Overdue invoices",
             icon = icon("calendar-times"), color = "red")
  })
  output$box_pending_gl <- renderValueBox({
    val <- sum(dff()$gl_status == "Pending")
    valueBox(comma(val), "Pending GL recon",
             icon = icon("spinner"), color = "yellow")
  })
  output$box_avg_amount <- renderValueBox({
    valueBox(
      paste0("KES ", comma(round(mean(dff()$invoice_amount)))),
      "Avg invoice value", icon = icon("calculator"), color = "navy")
  })
  
  # ── Monthly volume + on-time line ─────────────────────────
  output$chart_monthly <- renderPlotly({
    monthly <- dff() %>%
      group_by(month) %>%
      summarise(
        count      = n(),
        on_time_pct = round(mean(paid_on_time) * 100, 1),
        .groups = "drop"
      )
    
    plot_ly(monthly) %>%
      add_bars(x = ~month, y = ~count, name = "Invoice count",
               marker = list(color = "#AFA9EC")) %>%
      add_lines(x = ~month, y = ~on_time_pct, name = "On-time %",
                yaxis = "y2",
                line = list(color = "#1D9E75", width = 2)) %>%
      layout(
        yaxis  = list(title = "Invoice count"),
        yaxis2 = list(title = "On-time %", overlaying = "y",
                      side = "right", range = c(0, 100)),
        legend = list(orientation = "h"),
        hovermode = "x unified"
      )
  })
  # ── Department donut ──────────────────────────────────────
  output$chart_dept <- renderPlotly({
    dff() %>% count(department) %>%
      plot_ly(labels = ~department, values = ~n,
              type = "pie", hole = 0.45,
              marker = list(colors = c("#AFA9EC","#9FE1CB","#FAC775",
                                       "#F0997B","#85B7EB","#C0DD97"))) %>%
      layout(showlegend = TRUE)
  })
  
  # ── Cycle time by dept ────────────────────────────────────
  output$chart_cycle <- renderPlotly({
    dff() %>%
      group_by(department) %>%
      summarise(avg_days = round(mean(processing_days), 1), .groups="drop") %>%
      arrange(avg_days) %>%
      plot_ly(x = ~avg_days, y = ~reorder(department, avg_days),
              type = "bar", orientation = "h",
              marker = list(color = "#5DCAA5")) %>%
      layout(xaxis = list(title = "Avg processing days"),
             yaxis = list(title = ""))
  })
  
  # ── Exception rate trend ──────────────────────────────────
  output$chart_exception <- renderPlotly({
    dff() %>%
      group_by(month) %>%
      summarise(exc_pct = round(mean(has_exception) * 100, 1),
                .groups = "drop") %>%
      plot_ly(x = ~month, y = ~exc_pct,
              type = "scatter", mode = "lines+markers",
              line = list(color = "#E24B4A"),
              marker = list(color = "#E24B4A")) %>%
      add_lines(x = ~month,
                y = rep(10, nrow(dff() %>% count(month))),
                line = list(color = "#888780", dash = "dash"),
                name = "10% threshold") %>%
      layout(yaxis = list(title = "Exception %"),
             xaxis = list(title = ""))
  })
  
  # ── Vendor aging bar ──────────────────────────────────────
  output$chart_aging <- renderPlotly({
    aging_colors <- c("Current"    = "#9FE1CB",
                      "1-30 days"  = "#FAC775",
                      "31-60 days" = "#F0997B",
                      "60+ days"   = "#E24B4A")
    dff() %>%
      group_by(vendor, aging_bucket) %>%
      summarise(total = sum(invoice_amount), .groups = "drop") %>%
      plot_ly(x = ~total, y = ~vendor, color = ~aging_bucket,
              colors = aging_colors, type = "bar",
              orientation = "h") %>%
      layout(barmode = "stack",
             xaxis = list(title = "KES"),
             yaxis = list(title = ""),
             legend = list(title = list(text = "Aging bucket")))
  })
  
  # ── GL status donut ───────────────────────────────────────
  output$chart_gl <- renderPlotly({
    dff() %>% count(gl_status) %>%
      plot_ly(labels = ~gl_status, values = ~n,
              type = "pie", hole = 0.45,
              marker = list(colors = c("#1D9E75","#BA7517","#E24B4A"))) %>%
      layout(showlegend = TRUE)
  })
  
  # ── Aging value pie ───────────────────────────────────────
  output$chart_aging_pie <- renderPlotly({
    dff() %>%
      group_by(aging_bucket) %>%
      summarise(total = sum(invoice_amount), .groups = "drop") %>%
      plot_ly(labels = ~aging_bucket, values = ~total,
              type = "pie", hole = 0.35,
              marker = list(colors = c("#9FE1CB","#FAC775",
                                       "#F0997B","#E24B4A"))) %>%
      layout(showlegend = TRUE)
  })
  
  # ── Top overdue vendors ───────────────────────────────────
  output$chart_top_overdue <- renderPlotly({
    dff() %>%
      filter(days_overdue > 0) %>%
      group_by(vendor) %>%
      summarise(overdue_value = sum(invoice_amount), .groups = "drop") %>%
      slice_max(overdue_value, n = 8) %>%
      arrange(overdue_value) %>%
      plot_ly(x = ~overdue_value, y = ~reorder(vendor, overdue_value),
              type = "bar", orientation = "h",
              marker = list(color = "#F0997B")) %>%
      layout(xaxis = list(title = "KES overdue"),
             yaxis = list(title = ""))
  })
  
  # ── Invoice detail table ──────────────────────────────────
  output$invoice_table <- renderDT({
    dff() %>%
      select(invoice_id, vendor, department, gl_account,
             invoice_date, invoice_amount, processing_days,
             paid_on_time, aging_bucket, gl_status) %>%
      arrange(desc(invoice_date)) %>%
      datatable(
        filter  = "top",
        options = list(pageLength = 15, scrollX = TRUE),
        rownames = FALSE
      ) %>%
      formatCurrency("invoice_amount", currency = "KES ",
                     digits = 0, mark = ",") %>%
      formatStyle("paid_on_time",
                  backgroundColor = styleEqual(
                    c(TRUE, FALSE), c("#E1F5EE", "#FCEBEB"))) %>%
      formatStyle("gl_status",
                  backgroundColor = styleEqual(
                    c("Reconciled","Pending","Exception"),
                    c("#E1F5EE","#FAEEDA","#FCEBEB")))
  })
}

shinyApp(ui, server)