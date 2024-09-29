# API function to update the 3rd party system
import functions_framework 

# Register a CloudEvent function with the Functions Framework
@functions_framework.cloud_event
def update_wqi_value(cloud_event):

  # Access the CloudEvent data payload via cloud_event.data
  print(cloud_event.data)
  # code here
