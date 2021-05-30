# pull the base image
FROM node:alpine

# add app
COPY tq-workshop ./

# start app
CMD ["npm", "start"]