# pull the base image
FROM node:alpine

# add app
COPY test1/ ./

# start app
EXPOSE 3000
CMD ["npm", "start"]