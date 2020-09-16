//
//  AnnotationController.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 09.09.19.
//

import Foundation
import MapKit

class AnnotationController: NSObject {
    
    let mapView: MKMapView
    let channel: FlutterMethodChannel
    let registrar: FlutterPluginRegistrar
    
    public init(mapView :MKMapView, channel :FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.mapView = mapView
        self.channel = channel
        self.registrar = registrar
    }
    
    func getAnnotationView(annotation: FlutterAnnotation) -> MKAnnotationView{
        let identifier :String = annotation.id
        var annotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        let oldFlutterAnnotation = annotationView?.annotation as? FlutterAnnotation
        if annotationView == nil || oldFlutterAnnotation?.icon.iconType != annotation.icon.iconType {
            if annotation.icon.iconType == IconType.PIN {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else if annotation.icon.iconType == IconType.MARKER {
                if #available(iOS 11.0, *) {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                }
            } else if annotation.icon.iconType == IconType.CUSTOM {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView!.image = annotation.icon.image
                print("created CUSTOM MKAnnotationView")
            }
        } else {
            annotationView!.annotation = annotation
        }
        // If annotation is not visible set alpha to 0 and don't let the user interact with it
        if !annotation.isVisible! {
            annotationView!.canShowCallout = false
            annotationView!.alpha = CGFloat(0.0)
            annotationView!.isDraggable = false
            return annotationView!
        }

        if let rotationValue = annotation.rotation {
            UIView.animate(withDuration: 1, delay: 0, options: [.beginFromCurrentState, .allowAnimatedContent], animations: {
                // print(annotationView)
                annotationView!.transform = CGAffineTransform(rotationAngle: CGFloat(rotationValue * Double.pi / 180.0))
            })
        }

        annotationView!.canShowCallout = true
        annotationView!.alpha = CGFloat(annotation.alpha ?? 1.00)
        annotationView!.isDraggable = annotation.isDraggable ?? false

        annotationView!.layer.zPosition = CGFloat(annotation.zPosition ?? 0.0)
        
        return annotationView!
    }
    
    public func annotationsToAdd(annotations :NSArray) {
        for annotation in annotations {
            let annotationData :Dictionary<String, Any> = annotation as! Dictionary<String, Any>
            addAnnotation(annotationData: annotationData)
        }
    }
    
    
    public func annotationsToChange(annotations: NSArray) {
        let oldAnnotations :[MKAnnotation] = mapView.annotations
        for annotation in annotations {
            let annotationData :Dictionary<String, Any> = annotation as! Dictionary<String, Any>
            for oldAnnotation in oldAnnotations {
                if let oldFlutterAnnotation = oldAnnotation as? FlutterAnnotation {
                    if oldFlutterAnnotation.id == (annotationData["annotationId"] as! String) {
                        let newAnnotation = FlutterAnnotation.init(fromDictionary: annotationData, registrar: registrar)
                        if oldFlutterAnnotation != newAnnotation {
                            if !oldFlutterAnnotation.wasDragged {
                                updateAnnotationOnMap(oldAnnotation: oldFlutterAnnotation, newAnnotation: newAnnotation)
                            } else {
                                oldFlutterAnnotation.wasDragged = false
                            }
                        } 
                    }
                }
            }
        }
    }
    
    
    public func annotationsIdsToRemove(annotationIds: NSArray) {
        for annotationId in annotationIds {
            if let _annotationId :String = annotationId as? String {
                removeAnnotation(id: _annotationId)
            }
        }
    }
    
    
    public func onAnnotationClick(annotation :MKAnnotation) {
        if let flutterAnnotation :FlutterAnnotation = annotation as? FlutterAnnotation {
            flutterAnnotation.wasDragged = true
            channel.invokeMethod("annotation#onTap", arguments: ["annotationId" : flutterAnnotation.id])
        }
    }
    
    
    private func removeAnnotation(id: String) {
        for annotation in mapView.annotations {
            if let flutterAnnotation :FlutterAnnotation = annotation as? FlutterAnnotation {
                if flutterAnnotation.id == id {
                    mapView.removeAnnotation(flutterAnnotation)
                }
            }
        }
    }
    
    
    private func updateAnnotationOnMap(oldAnnotation: FlutterAnnotation, newAnnotation :FlutterAnnotation) {
        // check if the old annotation is still in view
        // if it is, just update all it's values
        if let oldAnnotationView = mapView.view(for: oldAnnotation) {
            if !newAnnotation.isVisible! {
                oldAnnotationView.canShowCallout = false
                oldAnnotationView.alpha = CGFloat(0.0)
                oldAnnotationView.isDraggable = false
            }
            else {
                oldAnnotationView.canShowCallout = true
                oldAnnotationView.alpha = CGFloat(newAnnotation.alpha ?? 1.00)
                oldAnnotationView.isDraggable = newAnnotation.isDraggable ?? false
            }
            oldAnnotationView.image = newAnnotation.icon.image
            if let rotationValue = newAnnotation.rotation, oldAnnotation.rotation != rotationValue {
                UIView.animate(withDuration: 1, delay: 0, options: [.beginFromCurrentState, .allowAnimatedContent], animations: {
                    oldAnnotationView.transform = CGAffineTransform(rotationAngle: CGFloat(rotationValue * Double.pi / 180.0))
                })
            }
            if let zPosition = newAnnotation.zPosition, oldAnnotation.zPosition != zPosition {
                oldAnnotationView.layer.zPosition = zPosition
            }
            oldAnnotation.coordinate = newAnnotation.coordinate
            oldAnnotation.icon = newAnnotation.icon
            oldAnnotation.title = newAnnotation.title
            oldAnnotation.subtitle = newAnnotation.subtitle
            oldAnnotation.image = newAnnotation.image
            oldAnnotation.alpha = newAnnotation.alpha
            oldAnnotation.isDraggable = newAnnotation.isDraggable
            oldAnnotation.wasDragged = newAnnotation.wasDragged
            oldAnnotation.isVisible = newAnnotation.isVisible
            oldAnnotation.icon = newAnnotation.icon
            oldAnnotation.rotation = newAnnotation.rotation
            oldAnnotation.zPosition = newAnnotation.zPosition
        }
        else {
            mapView.removeAnnotation(oldAnnotation)
            mapView.addAnnotation(newAnnotation)
        }
    }
    
    
    private func addAnnotation(annotationData: Dictionary<String, Any>) {
        let annotation :MKAnnotation = FlutterAnnotation(fromDictionary: annotationData, registrar: registrar)
        mapView.addAnnotation(annotation)
    }
}
