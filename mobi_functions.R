
MAP.FILL = "gray15"

# Returns gganimation of traffic arriving at or departing from a Mobi station.
# Each trip is treated as a vector, and the vectors grouped by station and
# added to create an overall traffic vector. The idea is to visualize patterns
# in where people are going TO (when starting at station X) or coming FROM
# (when arriving at station X.)
# This is not a very general function, just a convenience for this project.
animated.map <- function(
  data,
  direction = "departing",
  title.override = NULL,
  caption = "Andrew Luyt, 2022  |  Source: Mobi public data",
  transition_frames = 8,
  state_frames = 1,
  arrow.scale = 1
) {
  arrow.end <-  if (direction == "arriving") "first" else "last"
  base.arrow.scale = 0.003
  arrow.scale <- arrow.scale * base.arrow.scale

  # quo() and !! (unquote) work together to allow for selective use
  # of variable names in %>% pipes %>%. See vignette("programming")
  #
  # Set up variables and *titles
  if (direction == "arriving"){
    group_station <- quo(id_return)
    xvar = quo(lon_return)
    yvar = quo(lat_return)
    xend_var = quo(xend_arriving)
    yend_var = quo(yend_arriving)
    title = "Traffic arriving at Mobi bike stations     Hour: {next_state}"
    subtitle = "Arrows show the average direction of traffic into each station.\nDirection is averaged as a straight line from start station to end station.\nLonger arrows mean a stronger tendency for traffic to arrive from that direction."
  } else if (direction == "departing"){
    group_station <- quo(id_depart)
    xvar = quo(lon_depart)
    yvar = quo(lat_depart)
    xend_var = quo(xend_departing)
    yend_var = quo(yend_departing)
    title = "Traffic departing from Mobi bike stations     Hour: {next_state}"
    subtitle = "Arrows show the average direction of traffic out of each station.\nDirection is averaged as a straight line from start station to end station.\nLonger arrows mean a stronger tendency for traffic to travel to a destination in that direction."
  } else {
    stop("Direction must be 'arriving' or 'departing'")
  }

  if (is.character(title.override)) title = title.override

  # calculate vectors - slightly different for leaving vs arriving
  TMP_DF <- data %>%
    group_by(hour, !!group_station) %>%
    summarise(x = sum(lon_return - lon_depart),
              y = sum(lat_return - lat_depart),
              nrides = n(),
              lon_depart = first(lon_depart),
              lat_depart = first(lat_depart),
              lon_return = first(lon_return),
              lat_return = first(lat_return)) %>%
    ungroup() %>%
    rowwise() %>%
    mutate(angle = angle_from_x_axis(y,x),
           # calculate the endpoints of vectors for the two cases,
           # arriving at stations or departing from stations
           xend_arriving = lon_return - x * arrow.scale,
           yend_arriving = lat_return - y * arrow.scale,
           xend_departing = lon_depart + x * arrow.scale,
           yend_departing = lat_depart + y * arrow.scale) %>%
    ungroup() %>%
    # bin angles into 4 quadrants for colouring
    mutate(angle_group = cut_interval(angle, n = 4, labels = 1:4))

  # create animation
  p <- TMP_DF %>%
    ggplot(
      aes(x = !!xvar,
          y = !!yvar,
          xend = !!xend_var,
          yend = !!yend_var,
          # color = angle_group,
          color = nrides,
          # alpha = nrides,
          size = nrides,
          group = !!group_station)) +
    geom_sf(data = MAP, mapping = aes(), inherit.aes = FALSE, fill = MAP.FILL) +
    geom_sf(data = STANLEY_PARK, mapping = aes(), inherit.aes = FALSE, fill = MAP.FILL) +
    geom_segment(arrow = arrow(length = unit(0.01, "npc"), type = "closed", ends = arrow.end)) +
    # scale_alpha_continuous(range = c(0.2, 1)) +
    scale_color_viridis(option = "viridis", begin = 0.4) +
    scale_size_continuous(range = c(0.7, 1.7)) +
    xlim(c(-123.17, -123.06)) +
    ylim(c(49.254, 49.315)) +
    theme_map_dark +
    annotate("text", x = -123.1484, y = 49.3117, label = "Vancouver", color = "black", cex = 18) +
    annotate("text", x = -123.149, y = 49.312, label = "Vancouver", color = "grey60", cex = 18) +
    labs(subtitle = subtitle,
         caption = caption) +
    transition_states(hour, transition_length = transition_frames, state_length = state_frames) +
    ggtitle(title)
    # These two below are crashing knitr with apparent infinite recursion ??
    # enter_fade() +
    # exit_fade()
}

# Returns gganimation of traffic volume departing a Mobi station.
# This is not a very general function, just a convenience for this project.
volume_anim <- function(member = "24 Hour") {
  # member: string to define membership. Will be as filter with str_detect,
  # and for the animation's title.
  TMP_DF <- df %>%
    # filter(id_depart != id_return) %>%  # remove round trips
    filter(month(depart_time) == 7,
           str_detect(membership, member)) %>%
    group_by(hour, id_depart) %>%
    summarise(rides = n(),
              lon_depart = mean(lon_depart),
              lat_depart = mean(lat_depart))

  p <-
    TMP_DF %>%
    ggplot(aes(x = lon_depart,
               y = lat_depart,
               fill = rides,
               size = rides,
               group = id_depart)) +
    geom_sf(data = MAP, mapping = aes(), inherit.aes = FALSE, fill = MAP.FILL) +
    geom_sf(data = STANLEY_PARK, mapping = aes(), inherit.aes = FALSE, fill = MAP.FILL) +
    geom_point(pch = 21, color = "black") +
    xlim(c(-123.17, -123.06)) +
    ylim(c(49.254, 49.315)) +
    theme_map_dark +
    scale_fill_viridis(option = "viridis", begin = 0.25) +
    scale_size(range = c(2, 11)) +
    annotate("text", x = -123.1484, y = 49.3117, label = "Vancouver", color = "black", cex = 18) +
    annotate("text", x = -123.149, y = 49.312, label = "Vancouver", color = "grey60", cex = 18) +
    labs(subtitle = "Average traffic, by hour, out of each station in the Mobi network.",
         caption = "Andrew Luyt, 2022  |  Source: Mobi public data") +
    transition_states(hour, transition_length = 8, state_length = 1) +
    ggtitle(paste0("Station use by ", member, " Members, July 2021     Hour: {next_state}")) +
    shadow_wake(wake_length = 0.01,  wrap = TRUE)
  # Either below causes knitr to crash with:
  # Error: C stack usage  7969876 is too close to the limit
  # enter_fade() +
  # exit_fade()
}
