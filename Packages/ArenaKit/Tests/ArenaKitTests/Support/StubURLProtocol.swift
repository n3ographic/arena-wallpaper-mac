import Foundation
import Testing

/// All tests that use `StubURLProtocol` live in this suite: it runs them one at a time,
/// because the stub keeps its handler in shared state.
@Suite(.serialized) struct Network {}

/// Fake HTTP layer for `URLSession`: answers with `handler` and records every request.
final class StubURLProtocol: URLProtocol {
    struct Reply {
        var status: Int
        var headers: [String: String] = [:]
        var body = Data()
    }

    static var handler: ((URLRequest) -> Reply)?
    static var requests: [URLRequest] = []

    static func reset(_ handler: @escaping (URLRequest) -> Reply) {
        requests = []
        self.handler = handler
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func json(_ text: String, status: Int = 200) -> Reply {
        Reply(status: status, headers: ["Content-Type": "application/json"], body: Data(text.utf8))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var recorded = request
        if recorded.httpBody == nil, let stream = recorded.httpBodyStream {
            recorded.httpBody = Self.read(stream)
        }
        Self.requests.append(recorded)
        let reply = Self.handler?(recorded) ?? Reply(status: 500)
        let response = HTTPURLResponse(url: recorded.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// Decodes an `application/x-www-form-urlencoded` body.
func formFields(_ body: Data?) -> [String: String] {
    var components = URLComponents()
    components.percentEncodedQuery = String(decoding: body ?? Data(), as: UTF8.self)
    return Dictionary((components.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
}
