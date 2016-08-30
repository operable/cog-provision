value :AWSTemplateFormatVersion => "2010-09-09"
value :Description => "Cog ChatOps Platform"

include_template("parameters")
include_template("instance")
include_template("rds")
