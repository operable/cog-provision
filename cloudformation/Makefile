
SOURCES = cog.yaml cog-rds.yaml
S3_DEST = s3://operable-public/cloudformation
S3_CP_CMD = aws s3 cp

.PHONY: update

update:
	@for template in $(SOURCES); do \
		$(S3_CP_CMD) $$template $(S3_DEST)/$$template ; \
	done
