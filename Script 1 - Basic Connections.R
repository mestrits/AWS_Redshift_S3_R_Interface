### BASIC CONNECTIVITY TESTING - R STUDIO (Windows Deployment) via RODBC/RPOSTGRESQL to Amazon Redshift
### Ryan Anderson - June 2015

library(RPostgreSQL)  # uses DBI which was created by Hadley Wickham, so it must be good
library(RODBC) #

#########################################################
##  Step 0 - Let's Get Connected! - R PostgreSQL       ## 
#########################################################

# get password (so it doesnt show up in public in my GitHub Code)
password <- read.table(file="private.txt", header=FALSE) # where I'm holding pw outside public code , for now
password <- paste(password[1,1],sep="")  # but masks my password in public code (probably better way for this - explore registry)

### for reference - used section 3 from this post: https://github.com/snowplow/snowplow/wiki/Setting-up-R-to-perform-more-sophisticated-analysis-on-your-Snowplow-data
drv <- dbDriver("PostgreSQL")
con1 <- dbConnect(drv, host="hydrogen2.ccngjl5iyb5n.us-east-1.redshift.amazonaws.com", 
                 port="5439",
                 dbname="mydb", 
                 user="master_user", 
                 password=password)
con1 # check that you have a connection (e.g. <PostgreSQLConnection:(8892,0)>  )
### Make sure AWS has the security/access permissions opened up to allow Port 5439 access from YOUR IP (or all IPs)



#########################################################
##  Step 1 - Lets move a little data using RPostgreSQL ## 
#########################################################

### Creates the table directly in Redshift
dbSendQuery(con1, "create table iris_150 (sepallength float,sepalwidth float,petallength float,petalwidth float,species VARCHAR(100));")
dbListFields(con1,"iris_150")

### Takes the NATIVE "IRIS" Data set from R and uploads the 4X150 data set to Reshift. This is SLOW method, but good to test.
for (i in 1:(dim(iris)[1]) ) {
  query <- paste("insert into iris_150 values(",iris[i,1],",",iris[i,2],",",iris[i,3],",",iris[i,4],",","'",iris[i,5],"'",");",sep="")
  print(paste("row",i,"loading data >>  ",query))
  dbSendQuery(con1, query)
}

### OK - now let's read back 
data_readback1 <- dbGetQuery(con1, "select * from iris_150 where species like 'virginica' and petalwidth > '2'")  
dbRemoveTable(con1,"iris_150")  # and clean up toys


#########################################################
##  Step 2 - Let's Get Connected! - RODBC              ## 
#########################################################
# On this PC - what ODBC handles are options to open up a connection channel?  need to pre-configure and TEST OK your AMazon 
# odbcDataSources(type = c("all", "user", "system"))  ## show what ODBC Options are on system - should see Amazon

# get password (so it doesnt show up in public in my GitHub Code)
password <- read.table(file="private.txt", header=FALSE) # where I'm holding pw outside public code , for now
password <- paste(password[1,1],sep="")  # but masks my password in public code (probably better way for this - explore registry)

con2 <- odbcConnect("AWS_hydrogen2_source", uid = "master_user", pwd = password) # east region
con2 # works!  if a positive integer, you are connected
odbcGetInfo(con2)

##############################################################
##  Step 3 - Lets try the same basics with with RODBC now  ###  
##############################################################

# odbcTables(con2, catalog = NULL, schema = NULL, tableName = NULL, tableType = NULL, literal = FALSE)
## LIGHT TEST - THIS IS A BAD METHOD TO CREATE AND LOAD TABLES
#df <- data.frame(open=rnorm(50), low=rnorm(50), high=rnorm(50), close=rnorm(50))
df <- iris
colnames(df) <- tolower(colnames(df))  #careful about putting everything in lower case - LOWER CASE AWS (no "Low" must be "low")
head(df)
sqlSave(con2,df,"iris_150", rownames=F)  # SLOW - let's push data to REDSHIFT directly - 150 rows about 90 seconds

## READBACK - OK - if the table write / save - readback
data_readback2 <- sqlQuery(con2,"select * from iris_150 where species like 'virginica' and petalwidth > '1.75'") # reading is fast. subset
data_readback2 <- sqlQuery(con2,"select * from iris_150 where species = 'virginica'") # fast subset. this does work and shows up on AWS Redshift Dashboard

# as data frame
readback_df <- sqlFetch(con2, "iris_150", max = 11)
readback_df

sqlColumns(con2, "iris_150")

## Clean up our toys - ODBC - drop table and close channel
sqlDrop(con2, "iris_150", errors = FALSE) # clean up our toys
odbcClose(con2) ## clean up our toys


#### WORKS TO HERE

# Package consulted http://cran.r-project.org/web/packages/RPostgreSQL/RPostgreSQL.pdf 
# and https://code.google.com/p/rpostgresql/ helpful and http://docs.aws.amazon.com/redshift/latest/dg/c_redshift-and-postgres-sql.html
##### I had some problems with DBWRITETABLE - # dbWriteTable(con,"newTable",iris_200) # failed - so tried this to try to write to DB
# see http://rpostgresql.googlecode.com/svn/trunk/RPostgreSQL/inst/devTests/demo.r for reference
## TEST #1 - ONE BY ONE insert four rows into the table
# dbSendQuery(con, "insert into iris_200 values(5.1,3.5,1.4,0.2,'Iris-setosa');")
# dbSendQuery(con, "insert into iris_200 values(5.5,2.5,1.1,0.4,'Iris-setosa');")
# dframe <-dbReadTable(con,"iris_200") # ok
# dbRemoveTable(con,"iris_200")  # and clean up toys

