import Foundation

/// One v3 image block, as the Are.na API returns it.
func imageJSON(
    id: Int, contentType: String = "image/jpeg", width: Int? = 2000, height: Int? = 1200, fileSize: Int? = 5000,
    smallWidth: Int? = 300, mediumWidth: Int? = 640, largeWidth: Int? = 1200
) -> String {
    func number(_ value: Int?) -> String { value.map(String.init) ?? "null" }
    func version(_ name: String, _ w: Int?) -> String {
        #""\#(name)": {"src": "https://img/\#(id)-\#(name).jpg", "src_2x": "https://img/\#(id)-\#(name)@2x.jpg", "width": \#(number(w)), "height": null}"#
    }
    return """
    {"id": \(id), "type": "Image", "title": "t\(id)",
     "image": {"src": "https://img/\(id).jpg", "content_type": "\(contentType)",
               "width": \(number(width)), "height": \(number(height)), "file_size": \(number(fileSize)),
               \(version("small", smallWidth)), \(version("medium", mediumWidth)),
               \(version("large", largeWidth)), \(version("square", 400))}}
    """
}

func pageJSON(_ items: [String], more: Bool) -> String {
    #"{"data": [\#(items.joined(separator: ","))], "meta": {"has_more_pages": \#(more)}}"#
}
