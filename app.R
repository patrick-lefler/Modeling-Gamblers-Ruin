library(shiny)
library(ggplot2)
library(dplyr)
library(shinythemes)
library(markdown)

# -------------------------------------------------------------------------
# 1. README CONTENT & SOURCE CODE STRING
# -------------------------------------------------------------------------

# A. The Expanded "README" content for the Introduction Page
readme_content <- "
### Gambler's Ruin: A Markov Chain Simulation

#### 1. Historical Context: The Problem of Points
The concept of **Gambler's Ruin** stands as a pillar of probability theory, originating from the famous 1654 correspondence between **Blaise Pascal** and **Pierre de Fermat**. While their initial discussion focused on the 'Problem of Points' (how to fairly divide stakes in an unfinished game), the derived concept of 'Ruin' was later formalized by **Christiaan Huygens** in his 1657 treatise *De ratiociniis in ludo aleae*. 

It mathematically proves a counter-intuitive reality: in a fair game against an opponent with infinite wealth (the 'House'), a player with finite capital faces a probability of ruin of exactly **100%**. This was one of the first mathematical demonstrations that 'time' acts as an adversary to finite resources.

#### 2. Why Markov Chains?
This problem serves as the quintessential example of a **Discrete-Time Markov Chain**. It is the ideal modeling method because it relies on two distinct properties essential for risk analysis:
* **The Markov Property (Memorylessness):** The system has no memory. The probability of the next outcome depends *only* on the current state (current bankroll), not on the trajectory that led there. A 'hot streak' does not alter the mathematical probability of the next coin flip.
* **Absorbing States:** Unlike a standard random walk which oscillates indefinitely, this system contains 'traps.' State **0** (Ruin) and State **N** (Target) are absorbing barriers ($P_{0,0} = 1$). Once entered, they cannot be exited. This transforms the problem from a simple movement analysis into a **Survival Analysis** calculation, where the focus is on the probability of hitting the lower barrier before the upper one.

#### 3. Value for Risk Management
Static formulas provide a binary probability of failure, but they often mask the **path-dependent risks** that occur during the journey. This Shiny application provides a high-level overview of the risk management process by:
* **Visualizing Volatility & False Confidence:** The Monte Carlo simulation reveals that even paths destined for ruin often experience significant upward trends. These 'winning streaks' create false confidence in unstable strategies.
* **Non-Linear Sensitivity:** Risk is rarely linear. By adjusting the 'House Edge' ($p$) from 0.50 to just 0.48, you will observe a disproportionate collapse in survival rates. This demonstrates why small 'edges' in cybersecurity or trading compound into existential threats.
* **Convergence:** It visually demonstrates the Law of Large Numbers—showing how empirical risk settles into theoretical certainty over time.

#### 4. Real-World Applications
The mathematics of Gambler's Ruin provides a universal framework for analyzing any process involving **finite resources** and **random shocks**:
* **Insurance (Ruin Theory):** Actuaries utilize the **Cramér–Lundberg model** to determine the Minimum Capital Requirement (MCR). They must calculate the probability that a random sequence of claims depletes the carrier's surplus before premium income can replenish it.
* **Cybersecurity (The Asymmetric Threat):** This models the 'Defender’s Dilemma.' A defender operates with finite resources (time, budget, energy), while an advanced persistent threat (APT) effectively has infinite attempts. If the probability of a successful defense is anything less than 100% ($p < 1$), the probability of an eventual breach approaches certainty as $t \\to \\infty$.
* **Algorithmic Trading:** High-frequency strategies, particularly **Martingale** or 'Grid Trading' systems, often rely on mean reversion. This model demonstrates that without a 'Stop Loss' (an artificial absorbing barrier), doubling down on losses inevitably leads to total account liquidation.
"

# B. The FULL Source Code (Stored as a string to display in the App)
app_source_code <- '
library(shiny)
library(ggplot2)
library(dplyr)
library(shinythemes)
library(markdown)

ui <- navbarPage(
  title = "Gamblers Ruin",
  theme = shinytheme("sandstone"),
  
  # PAGE 1: INTRODUCTION
  tabPanel("Introduction",
           fluidRow(
             column(8, offset = 2,
                    wellPanel(
                      markdown(readme_content),
                      hr(),
                      h4("Key Takeaway"),
                      p("Even with a 50/50 fair game, a gambler with finite wealth playing against 
                        a house with infinite wealth will eventually go broke with probability 1.")
                    )
             )
           )
  ),
  
  # PAGE 2: CALCULATIONS
  tabPanel("Calculations & Data Visualization",
           sidebarLayout(
             sidebarPanel(
               h4("Game Parameters"),
               sliderInput("start_cap", "Initial Capital ($):", min = 10, max = 100, value = 50),
               sliderInput("target_cap", "Target Capital ($):", min = 20, max = 200, value = 100),
               # MODIFICATION 1: Step changed to 0.005
               sliderInput("prob_win", "Probability of Winning (p):", 
                           min = 0.40, max = 0.60, value = 0.48, step = 0.005),
               hr(),
               h4("Simulation Settings"),
               sliderInput("n_sims", "Number of Simulations:", min = 100, max = 1000, value = 200),
               actionButton("run", "Run Simulation", class = "btn-primary"),
               hr(),
               htmlOutput("theory_text") 
             ),
             mainPanel(
               tabsetPanel(
                 tabPanel("1. Random Walks", plotOutput("distPlot")),
                 tabPanel("2. Convergence to Math", plotOutput("convPlot"))
               )
             )
           )
  ),
  
  # PAGE 3: CODE VIEW
  tabPanel("Code",
           fluidRow(
             column(10, offset = 1,
                    h3("Full Application Code"),
                    p("Below is the complete R code used to build this Shiny application."),
                    verbatimTextOutput("code_display")
             )
           )
  ),
  
  # PAGE 4: SESSION INFO
  tabPanel("R Session Info",
           fluidRow(
             column(10, offset = 1,
                    h3("Session Information"),
                    verbatimTextOutput("session_info")
             )
           )
  )
)

server <- function(input, output) {
  
  # 1. Theoretical Probability Calculation
  theoretical_prob <- reactive({
    p <- input$prob_win
    q <- 1 - p
    i <- input$start_cap
    N <- input$target_cap
    if (p == 0.5) return(i / N)
    ratio <- q / p
    return((1 - ratio^i) / (1 - ratio^N))
  })
  
  # 2. Simulation Logic
  sim_data <- eventReactive(input$run, {
    results_list <- vector("list", input$n_sims)
    withProgress(message = "Running Simulations...", value = 0, {
      for(k in 1:input$n_sims) {
        balance <- input$start_cap
        history <- c(balance)
        while(balance > 0 && balance < input$target_cap) {
          outcome <- sample(c(1, -1), 1, prob = c(input$prob_win, 1 - input$prob_win))
          balance <- balance + outcome
          history <- c(history, balance)
          if(length(history) > 5000) break 
        }
        final_state <- tail(history, 1)
        result_status <- ifelse(final_state >= input$target_cap, 1, 0)
        
        path_df <- if(k <= 100) {
          data.frame(Step = 0:(length(history)-1), Balance = history, SimID = k)
        } else { NULL }
        
        results_list[[k]] <- list(result = result_status, path = path_df)
        if(k %% 50 == 0) incProgress(50/input$n_sims)
      }
    })
    return(results_list)
  })
  
  # 3. Plotting Logic
  output$distPlot <- renderPlot({
    req(sim_data())
    paths <- lapply(sim_data(), function(x) x$path)
    paths_df <- do.call(rbind, paths)
    ggplot(paths_df, aes(x = Step, y = Balance, group = SimID)) +
      geom_line(alpha = 0.4, color = "#3E3F3A", linewidth = 0.5) + 
      geom_hline(yintercept = input$target_cap, linetype = "dashed", color = "#98C46C", linewidth = 1) + 
      geom_hline(yintercept = 0, linetype = "dashed", color = "#D9534F", linewidth = 1) + 
      labs(title = "Monte Carlo Paths (First 100 displayed)", 
           y = "Bankroll ($)") + theme_minimal()
  })
  
  output$convPlot <- renderPlot({
    req(sim_data())
    results <- sapply(sim_data(), function(x) x$result)
    cum_wins <- cumsum(results)
    n_trials <- 1:length(results)
    conv_df <- data.frame(Trial = n_trials, WinRate = cum_wins / n_trials)
    theo_val <- theoretical_prob()
    
    # Dynamic Axis Calculation
    all_vals <- c(conv_df$WinRate, theo_val)
    y_min <- max(0, min(all_vals) - 0.05)
    y_max <- min(1, max(all_vals) + 0.05)
    
    ggplot(conv_df, aes(x = Trial, y = WinRate)) +
      geom_line(linewidth = 1, color = "#F0AD4E") + 
      # MODIFICATION 2 & 3: Color changed to #000080, linewidth to 0.25
      geom_hline(aes(yintercept = theo_val, linetype = "Theoretical Probability"), 
                 color = "#000080", linewidth = 0.25) +
      scale_y_continuous(labels = scales::percent, limits = c(y_min, y_max)) +
      scale_linetype_manual(name = "", values = c("Theoretical Probability" = "dashed")) +
      labs(title = "Convergence to Theoretical Probability", y = "Cumulative Win Probability") + 
      theme_minimal() + theme(legend.position = "bottom")
  })
  
  output$theory_text <- renderUI({
    val <- theoretical_prob() * 100
    HTML(paste0("<b>Theoretical Probability of Success:</b> ", round(val, 3), "%<br>",
                "<small>Based on Gamblers Ruin Formula</small>"))
  })

  output$code_display <- renderText({ app_source_code })
  output$session_info <- renderPrint({ sessionInfo() })
}
shinyApp(ui = ui, server = server)
'

# -------------------------------------------------------------------------
# 2. UI DEFINITION
# -------------------------------------------------------------------------

ui <- navbarPage(
  title = "Gambler's Ruin",
  theme = shinytheme("sandstone"),
  
  # PAGE 1: INTRODUCTION (README)
  tabPanel("Introduction",
           fluidRow(
             column(8, offset = 2,
                    wellPanel(
                      # Using Markdown to render the text nicely
                      markdown(readme_content),
                      hr(),
                      h4("Key Takeaway"),
                      p("Even with a 50/50 fair game, a gambler with finite wealth playing against a 'house' with infinite wealth will eventually go broke with probability 1. This app visualizes that journey.")
                    )
             )
           )
  ),
  
  # PAGE 2: CALCULATIONS (The Main App)
  tabPanel("Calculations & Data Visualization",
           sidebarLayout(
             sidebarPanel(
               h4("Game Parameters"),
               sliderInput("start_cap", "Initial Capital ($):", min = 10, max = 100, value = 50),
               sliderInput("target_cap", "Target Capital ($):", min = 20, max = 200, value = 100),
               
               # MODIFICATION 1: Step changed to 0.005
               sliderInput("prob_win", "Probability of Winning (p):", 
                           min = 0.40, max = 0.60, value = 0.48, step = 0.005),
               
               hr(),
               h4("Simulation Settings"),
               sliderInput("n_sims", "Number of Simulations:", min = 100, max = 1000, value = 200),
               actionButton("run", "Run Simulation", class = "btn-primary"),
               
               hr(),
               htmlOutput("theory_text") 
             ),
             
             mainPanel(
               tabsetPanel(
                 tabPanel("1. Random Walks", plotOutput("distPlot")),
                 tabPanel("2. Convergence to Math", plotOutput("convPlot"))
               )
             )
           )
  ),
  
  # PAGE 3: CODE VIEW
  tabPanel("Code",
           fluidRow(
             column(10, offset = 1,
                    h3("Full Application Code"),
                    p("Below is the complete R code utilized in this Shiny application."),
                    # Using verbatimTextOutput to preserve code formatting
                    verbatimTextOutput("code_display")
             )
           )
  ),
  
  # PAGE 4: SESSION INFO
  tabPanel("R Session Info",
           fluidRow(
             column(10, offset = 1,
                    h3("Session Information"),
                    verbatimTextOutput("session_info")
             )
           )
  )
)

# -------------------------------------------------------------------------
# 3. SERVER LOGIC
# -------------------------------------------------------------------------

server <- function(input, output) {
  
  # --- LOGIC FOR CALCULATION PAGE ---
  
  # 1. Calculate Theoretical Probability
  theoretical_prob <- reactive({
    p <- input$prob_win
    q <- 1 - p
    i <- input$start_cap
    N <- input$target_cap
    
    if (p == 0.5) {
      return(i / N)
    } else {
      ratio <- q / p
      prob <- (1 - ratio^i) / (1 - ratio^N)
      return(prob)
    }
  })
  
  # 2. Run the Simulation
  sim_data <- eventReactive(input$run, {
    results_list <- vector("list", input$n_sims)
    
    withProgress(message = 'Running Simulations...', value = 0, {
      for(k in 1:input$n_sims) {
        balance <- input$start_cap
        history <- c(balance)
        
        # Run single game loop
        while(balance > 0 && balance < input$target_cap) {
          outcome <- sample(c(1, -1), 1, prob = c(input$prob_win, 1 - input$prob_win))
          balance <- balance + outcome
          history <- c(history, balance)
          if(length(history) > 5000) break 
        }
        
        final_state <- tail(history, 1)
        result_status <- ifelse(final_state >= input$target_cap, 1, 0)
        
        # Store path for the first 100 sims
        path_df <- if(k <= 100) {
          data.frame(Step = 0:(length(history)-1), Balance = history, SimID = k)
        } else { NULL }
        
        results_list[[k]] <- list(result = result_status, path = path_df)
        if(k %% 50 == 0) incProgress(50/input$n_sims)
      }
    })
    return(results_list)
  })
  
  # 3. Plot 1: Random Walks
  output$distPlot <- renderPlot({
    req(sim_data())
    paths <- lapply(sim_data(), function(x) x$path)
    paths_df <- do.call(rbind, paths)
    
    ggplot(paths_df, aes(x = Step, y = Balance, group = SimID)) +
      geom_line(alpha = 0.4, color = "#000080", linewidth = 0.25) + 
      geom_hline(yintercept = input$target_cap, linetype = "dashed", color = "#98C46C", linewidth = 1) + 
      geom_hline(yintercept = 0, linetype = "dashed", color = "#D9534F", linewidth = 1) + 
      labs(title = "Monte Carlo Paths (First 100 displayed)",
           subtitle = "Visualizing the volatility of individual gamblers",
           y = "Bankroll ($)") +
      theme_minimal()
  })
  
  # 4. Plot 2: Convergence (DYNAMIC AXIS UPDATE)
  output$convPlot <- renderPlot({
    req(sim_data())
    results <- sapply(sim_data(), function(x) x$result)
    cum_wins <- cumsum(results)
    n_trials <- 1:length(results)
    running_avg <- cum_wins / n_trials
    
    conv_df <- data.frame(Trial = n_trials, WinRate = running_avg)
    theo_val <- theoretical_prob()
    
    # --- Dynamic Axis Calculation ---
    all_vals <- c(conv_df$WinRate, theo_val)
    # Add a 5% buffer to the view, but clamp it between 0 and 1
    y_min <- max(0, min(all_vals) - 0.05)
    y_max <- min(1, max(all_vals) + 0.05)
    
    ggplot(conv_df, aes(x = Trial, y = WinRate)) +
      geom_line(linewidth = 1, color = "#F0AD4E") + 
      
      # MODIFICATION 2 & 3: Color changed to #000080 (Navy), linewidth to 0.25
      geom_hline(aes(yintercept = theo_val, linetype = "Theoretical Probability"), 
                 color = "#000000", linewidth = 0.5) +
      
      scale_y_continuous(labels = scales::percent, limits = c(y_min, y_max)) +
      scale_linetype_manual(name = "", values = c("Theoretical Probability" = "dashed")) +
      labs(title = "Convergence to Theoretical Probability",
           subtitle = "As N increases, the Empirical Win Rate settles on the Theoretical Math",
           y = "Cumulative Win Probability") +
      theme_minimal() +
      theme(legend.position = "bottom")
  })
  
  # 5. Text Output
  output$theory_text <- renderUI({
    val <- theoretical_prob() * 100
    HTML(paste0("<b>Theoretical Probability of Success:</b> ", round(val, 3), "%<br>",
                "<small>Based on Gambler's Ruin Formula</small>"))
  })
  
  # --- LOGIC FOR OTHER PAGES ---
  
  # Display the FULL code stored in variable 'app_source_code'
  output$code_display <- renderText({
    app_source_code
  })
  
  output$session_info <- renderPrint({
    sessionInfo()
  })
}

shinyApp(ui = ui, server = server)