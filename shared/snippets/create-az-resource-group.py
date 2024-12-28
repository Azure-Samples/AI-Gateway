
# type: ignore

import datetime

resource_group_stdout = ! az group create --name {resource_group_name} --location {resource_group_location}

if resource_group_stdout.n.startswith("ERROR"):
    print(resource_group_stdout)
else:
    print(f"✅ Azure Resource Group {resource_group_name} created ⌚ {datetime.datetime.now().time()}")
