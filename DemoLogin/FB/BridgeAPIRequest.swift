class BridgeAPIRequest {

}

typealias BridgeAPIResponseBlock = (BridgeAPIResponse) ->Void
class BridgeAPIResponse {

	static func cancelled(with request: BridgeAPIRequest) -> BridgeAPIResponse {
		return BridgeAPIResponse()
	}

}
