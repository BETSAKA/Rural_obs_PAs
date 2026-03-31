# Now when we do:
source("data/ROS_MDG_microdata/2025/cspro_files/MODULE_RMQ.R")
# it creates module_rmq with the following content
head(module_rmq)
str(module_rmq)
# I would like to custom this output so it corresponds to the structure
# (ie. not the variable names or data content, but the way values are stored and labeled)
# of the older data that I have in dta files
rmq_2014 <- haven::read_dta("data/ROS_MDG_microdata/2014/res_rmq.dta")
head(rmq_2014)
str(rmq_2014)
# Ultimately, what I want to do is to save module_rmq as "data/ROS_MDG_microdata/2025/res_rmq.dta" and obtain the
# same type of data when I read it with read_dta as rmq_2014
