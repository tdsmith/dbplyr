#' Connect to postgresql.
#' 
#' Use \code{src_postgres} to connect to an existing postgresql database,
#' and \code{tbl} to connect to tables within that database. 
#' If you are running a local postgresql database, leave all parameters set as 
#' their defaults to connect. If you're connecting to a remote database, 
#' ask your database administrator for the values of these variables.
#' 
#' @template db-info
#' @param dbname Database name
#' @param host,port Host name and port number of database
#' @param user,password User name and password (if needed)
#' @param ... for the src, other arguments passed on to the underlying
#'   database connector, \code{dbConnect}. For the tbl, included for 
#'   compatibility with the generic, but otherwise ignored.
#' @param src a postgres src created with \code{src_postgres}.
#' @param from Either a string giving the name of table in database, or
#'   \code{\link{sql}} described a derived table or compound join.
#' @export
#' @examples
#' \dontrun{
#' # Connection basics ---------------------------------------------------------
#' # To connect to a database first create a src:
#' my_db <- src_postgres(host = "blah.com", user = "hadley",
#'   password = "pass")
#' # Then reference a tbl within that src
#' my_tbl <- tbl(my_db, "my_table")
#' }
#'
#' # Here we'll use the Lahman database: to create your own local copy,
#' # create a local database called "lahman", or tell lahman_postgres() how to 
#' # a database that you can write to
#' 
#' if (has_lahman("postgres")) {
#' # Methods -------------------------------------------------------------------
#' batting <- tbl(lahman_postgres(), "Batting")
#' dim(batting)
#' colnames(batting)
#' head(batting)
#'
#' # Data manipulation verbs ---------------------------------------------------
#' filter(batting, yearID > 2005, G > 130)
#' select(batting, playerID:lgID)
#' arrange(batting, playerID, desc(yearID))
#' summarise(batting, G = mean(G), n = n())
#' mutate(batting, rbi2 = if(is.null(AB)) 1.0 * R / AB else 0)
#' 
#' # note that all operations are lazy: they don't do anything until you
#' # request the data, either by `print()`ing it (which shows the first ten 
#' # rows), by looking at the `head()`, or `collect()` the results locally.
#'
#' system.time(recent <- filter(batting, yearID > 2010))
#' system.time(collect(recent))
#' 
#' # Group by operations -------------------------------------------------------
#' # To perform operations by group, create a grouped object with group_by
#' players <- group_by(batting, playerID)
#' group_size(players)
#'
#' summarise(players, mean_g = mean(G), best_ab = max(AB))
#' best_year <- filter(players, AB == max(AB) || G == max(G))
#' progress <- mutate(players, cyear = yearID - min(yearID) + 1, 
#'  rank(desc(AB)), cumsum(AB, yearID))
#'  
#' # When you group by multiple level, each summarise peels off one level
#' per_year <- group_by(batting, playerID, yearID)
#' stints <- summarise(per_year, stints = max(stint))
#' filter(stints, stints > 3)
#' summarise(stints, max(stints))
#' mutate(stints, cumsum(stints, yearID))
#'
#' # Joins ---------------------------------------------------------------------
#' player_info <- select(tbl(lahman_postgres(), "Master"), playerID, hofID, 
#'   birthYear)
#' hof <- select(filter(tbl(lahman_postgres(), "HallOfFame"), inducted == "Y"),
#'  hofID, votedBy, category)
#' 
#' # Match players and their hall of fame data
#' inner_join(player_info, hof)
#' # Keep all players, match hof data where available
#' left_join(player_info, hof)
#' # Find only players in hof
#' semi_join(player_info, hof)
#' # Find players not in hof
#' anti_join(player_info, hof)
#'
#' # Arbitrary SQL -------------------------------------------------------------
#' # You can also provide sql as is, using the sql function:
#' batting2008 <- tbl(lahman_postgres(),
#'   sql('SELECT * FROM "Batting" WHERE "yearID" = 2008'))
#' batting2008
#' }
src_postgres <- function(dbname = NULL, host = NULL, port = NULL, user = NULL, 
                         password = NULL, ...) {
  if (!require("RPostgreSQL")) {
    stop("RPostgreSQL package required to connect to postgres db", call. = FALSE)
  }

  user <- user %||% if (in_travis()) "postgres" else ""
  
  con <- dbi_connect(PostgreSQL(), host = host %||% "", dbname = dbname %||% "", 
    user = user, password = password %||% "", port = port %||% "", ...)
  info <- db_info(con)
  
  src_sql("postgres", con, 
    info = info, disco = db_disconnector(con, "postgres"))
}

#' @method tbl src_postgres
#' @export
#' @rdname src_postgres
tbl.src_postgres <- function(src, from, ...) {
  tbl_sql("postgres", src = src, from = from, ...)
}

#' @S3method brief_desc src_postgres
brief_desc.src_postgres <- function(x) {
  info <- x$info
  host <- if (info$host == "") "localhost" else info$host
  
  paste0("postgres ", info$serverVersion, " [", info$user, "@", 
    host, ":", info$port, "/", info$dbname, "]")
}

#' @S3method translate_env src_postgres
translate_env.src_postgres <- function(x) {
  sql_variant(
    n = function() sql("count(*)"),
    # Extra aggregate functions
    cor = sql_prefix("corr"),
    cov = sql_prefix("covar_samp"),
    sd =  sql_prefix("stddev_samp"),
    var = sql_prefix("var_samp"),
    all = sql_prefix("bool_and"),
    any = sql_prefix("bool_or"),
    as.numeric = function(x) build_sql("CAST(", x, " AS NUMERIC)"),
    as.integer = function(x) build_sql("CAST(", x, " AS INTEGER)"),
    paste = function(x, collapse) build_sql("string_agg(", x, collapse, ")")
  )
}

#' @export
translate_window_env.src_postgres <- function(x, group_by = NULL, 
                                              order_by = NULL) {
  translate_window_env_base(x, group_by = group_by, order_by = order_by)
}
