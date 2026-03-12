<policies>
	<inbound>
		<base />
        <set-variable name="requestBody"
                    value="@(context.Request.Body.As<string>(preserveContent: true))" />
		<set-variable name="mcpTool" value="@{
			var body = (string)context.Variables["requestBody"];
			if (string.IsNullOrEmpty(body)) { return ""; }
			var json = Newtonsoft.Json.Linq.JObject.Parse(body);
			var p = json["params"] as Newtonsoft.Json.Linq.JObject;
			if (p == null) { return ""; }
			return (string)p["name"] ?? "";
		}" />
		<trace source="MCPContext" severity="information">
			<message>MCPContext</message>
			<metadata name="tool" value="@((string)context.Variables["mcpTool"])" />
		</trace>
	</inbound>
	<backend>
		<base />
	</backend>
	<outbound>
		<base />
	</outbound>
	<on-error>
		<base />
	</on-error>
</policies>