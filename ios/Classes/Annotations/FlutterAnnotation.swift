//
//  FlutterAnnotation.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 07.03.20.
//

import Foundation
import MapKit

class FlutterAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var id :String!
    var title: String?
    var subtitle: String?
    var image: UIImage?
    var alpha: Double?
    var isDraggable: Bool?
    var wasDragged: Bool = false
    var isVisible: Bool? = true
    var icon: AnnotationIcon = AnnotationIcon.init()
    var rotation: Double?
    
    public init(fromDictionary annotationData: Dictionary<String, Any>, registrar: FlutterPluginRegistrar) {
        let position :Array<Double> = annotationData["position"] as! Array<Double>
        let infoWindow :Dictionary<String, Any> = annotationData["infoWindow"] as! Dictionary<String, Any>
        let lat: Double = position[0]
        let long: Double = position[1]
        self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        self.title = infoWindow["title"] as? String
        self.subtitle = infoWindow["snippet"] as? String
        self.id = annotationData["annotationId"] as? String
        self.isVisible = annotationData["visible"] as? Bool
        self.isDraggable = annotationData["draggable"] as? Bool
        self.rotation = annotationData["rotation"] as? Double
        if let alpha: Double = annotationData["alpha"] as? Double {
            self.alpha = alpha
        }
        if let iconData: Array<Any> = annotationData["icon"] as? Array<Any> {
            self.icon = FlutterAnnotation.getAnnotationIcon(iconData: iconData, registrar: registrar, annotationId: id)
        }
    }
    
    static private func getAnnotationIcon(iconData: Array<Any>, registrar: FlutterPluginRegistrar, annotationId: String) -> AnnotationIcon {
        let iconTypeMap: Dictionary<String, IconType> = ["fromAssetImage": IconType.CUSTOM, "defaultAnnotation": IconType.PIN, "markerAnnotation": IconType.MARKER]
        var icon: AnnotationIcon
        let iconType: IconType = iconTypeMap[iconData[0] as! String] ?? .PIN
        var scaleParam: CGFloat?
       
        if iconType == .CUSTOM {
            let assetPath: String = iconData[1] as! String
            scaleParam = CGFloat(iconData[2] as? Double ?? 1.0)
            icon = AnnotationIcon(named: registrar.lookupKey(forAsset: assetPath), iconType: iconType, id: annotationId, iconScale: scaleParam)
        } else {
            icon = AnnotationIcon(named: "", iconType: iconType, id: annotationId)
        }
        return icon
    }
    
    static func == (lhs: FlutterAnnotation, rhs: FlutterAnnotation) -> Bool {
        return  lhs.id == rhs.id && lhs.title == rhs.title && lhs.subtitle == rhs.subtitle && lhs.image == rhs.image && lhs.alpha == rhs.alpha
            && lhs.isDraggable == rhs.isDraggable && lhs.wasDragged == rhs.wasDragged && lhs.isVisible == rhs.isVisible && lhs.icon == rhs.icon 
            && lhs.rotation == rhs.rotation && lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
    
    static func != (lhs: FlutterAnnotation, rhs: FlutterAnnotation) -> Bool {
        return !(lhs == rhs)
    }
}
