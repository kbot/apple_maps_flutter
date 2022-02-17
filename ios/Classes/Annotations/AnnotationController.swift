//
//  AnnotationController.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 09.09.19.
//

import Foundation
import MapKit

extension AppleMapController: AnnotationDelegate {

    func getAnnotationView(annotation: FlutterAnnotation) -> MKAnnotationView {
        let identifier: String = annotation.id
        var annotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        let oldFlutterAnnotation = annotationView?.annotation as? FlutterAnnotation
        if annotationView == nil || oldFlutterAnnotation?.icon.iconType != annotation.icon.iconType {
            if annotation.icon.iconType == IconType.PIN {
                annotationView = getPinAnnotationView(annotation: annotation, id: identifier)
            } else if annotation.icon.iconType == IconType.MARKER {
                annotationView = getMarkerAnnotationView(annotation: annotation, id: identifier)
            } else if annotation.icon.iconType == .CUSTOM_FROM_ASSET || annotation.icon.iconType == .CUSTOM_FROM_BYTES {
                annotationView = getCustomAnnotationView(annotation: annotation, id: identifier)
            }
        }
        guard annotationView != nil else {
            return MKAnnotationView()
        }
        annotationView!.annotation = annotation
        // If annotation is not visible set alpha to 0 and don't let the user interact with it
        if !annotation.isVisible! {
            annotationView!.canShowCallout = false
            annotationView!.alpha = CGFloat(0.0)
            annotationView!.isDraggable = false
            return annotationView!
        }
        if annotation.icon.iconType != .MARKER {
            initInfoWindow(annotation: annotation, annotationView: annotationView!)
            if annotation.icon.iconType != .PIN {
                let x = (0.5 - annotation.anchor.x) * Double(annotationView!.frame.size.width)
                let y = (0.5 - annotation.anchor.y) * Double(annotationView!.frame.size.height)
                annotationView!.centerOffset = CGPoint(x: x, y: y)
            }
        }
        if let rotationValue = annotation.rotation {
            UIView.animate(withDuration: 1, delay: 0, options: [.beginFromCurrentState, .allowAnimatedContent], animations: {
                annotationView!.transform = CGAffineTransform(rotationAngle: CGFloat(rotationValue * Double.pi / 180.0))
            })
        }
        annotationView!.canShowCallout = true
        annotationView!.alpha = CGFloat(annotation.alpha ?? 1.00)
        annotationView!.isDraggable = annotation.isDraggable ?? false

        annotationView!.layer.zPosition = CGFloat(annotation.zPosition ?? 0.0)
        
        return annotationView!
    }

    func annotationsToAdd(annotations :NSArray) {
        for annotation in annotations {
            let annotationData :Dictionary<String, Any> = annotation as! Dictionary<String, Any>
            addAnnotation(annotationData: annotationData)
        }
    }

    func annotationsToChange(annotations: NSArray) {
        let oldAnnotations :[MKAnnotation] = self.mapView.annotations
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

    func annotationsIdsToRemove(annotationIds: NSArray) {
        for annotationId in annotationIds {
            if let _annotationId :String = annotationId as? String {
                removeAnnotation(id: _annotationId)
            }
        }
    }
    
    func removeAllAnnotations() {
        self.mapView.removeAnnotations(self.mapView.annotations)
    }

    func onAnnotationClick(annotation :MKAnnotation) {
        if let flutterAnnotation :FlutterAnnotation = annotation as? FlutterAnnotation {
            flutterAnnotation.wasDragged = true
            channel.invokeMethod("annotation#onTap", arguments: ["annotationId" : flutterAnnotation.id])
        }
    }
    
    func showAnnotation(with id: String) {
        let annotation = self.getAnnotation(with: id)
        guard annotation != nil else {
            return
        }
        self.mapView.selectAnnotation(annotation!, animated: true)
    }

    func hideAnnotation(with id: String) {
        let annotation = self.getAnnotation(with: id)
        guard annotation != nil else {
            return
        }
        self.mapView.deselectAnnotation(annotation!, animated: true)
    }

    func isAnnotationSelected(with id: String) -> Bool {
        return self.mapView.selectedAnnotations.contains(where: { annotation in return self.getAnnotation(with: id) == (annotation as? FlutterAnnotation)})
    }


    private func removeAnnotation(id: String) {
        if let flutterAnnotation :FlutterAnnotation = self.getAnnotation(with: id) {
            self.mapView.removeAnnotation(flutterAnnotation)
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
            removeAnnotation(id: oldAnnotation.id)
            mapView.addAnnotation(newAnnotation)
        }
    }

    private func initInfoWindow(annotation: FlutterAnnotation, annotationView: MKAnnotationView) {
        let x = self.getInfoWindowXOffset(annotationView: annotationView, annotation: annotation)
        let y = self.getInfoWindowYOffset(annotationView: annotationView, annotation: annotation)
        annotationView.calloutOffset = CGPoint(x: x, y: y)
        if #available(iOS 9.0, *) {
            let lines = annotation.subtitle?.split(whereSeparator: { $0.isNewline })
            if lines != nil {
                let customCallout = UIStackView()
                customCallout.axis = .vertical
                customCallout.alignment = .fill
                customCallout.distribution = .fill
                for line in lines! {
                    let subtitle = UILabel()
                    subtitle.text = String(line)
                    customCallout.addArrangedSubview(subtitle)
                }
                annotationView.detailCalloutAccessoryView = customCallout
            }
        }
    }

    private func getAnnotation(with id: String) -> FlutterAnnotation? {
        return self.mapView.annotations.filter { annotation in return (annotation as? FlutterAnnotation)?.id == id }.first as? FlutterAnnotation
    }

    private func addAnnotation(annotationData: Dictionary<String, Any>) {
        let annotation :MKAnnotation = FlutterAnnotation(fromDictionary: annotationData, registrar: registrar)
        self.mapView.addAnnotation(annotation)
    }

    private func getPinAnnotationView(annotation: MKAnnotation, id: String) -> MKPinAnnotationView {
        if #available(iOS 11.0, *) {
            self.mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: id)
            return self.mapView.dequeueReusableAnnotationView(withIdentifier: id, for: annotation) as! MKPinAnnotationView
        } else {
            return MKPinAnnotationView.init(annotation: annotation, reuseIdentifier: id)
        }
    }

    private func getMarkerAnnotationView(annotation: MKAnnotation, id: String) -> MKAnnotationView {
        if #available(iOS 11.0, *) {
            self.mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: id)
            return self.mapView.dequeueReusableAnnotationView(withIdentifier: id, for: annotation)
        } else {
            return MKPinAnnotationView.init(annotation: annotation, reuseIdentifier: id)
        }
    }

    private func getCustomAnnotationView(annotation: FlutterAnnotation, id: String) -> MKAnnotationView {
        let annotationView: MKAnnotationView?
        if #available(iOS 11.0, *) {
            self.mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: id)
            annotationView = self.mapView.dequeueReusableAnnotationView(withIdentifier: id, for: annotation)
        } else {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
        }
        annotationView?.image = annotation.icon.image
        return annotationView!
    }

    private func getInfoWindowXOffset(annotationView: MKAnnotationView, annotation: FlutterAnnotation) -> CGFloat {
        if annotation.icon.iconType == .PIN {
            return annotationView.frame.origin.x - (annotationView.frame.origin.x * CGFloat(annotation.calloutOffset.x))
        }
        return annotationView.frame.origin.x + (annotationView.frame.width * CGFloat(annotation.calloutOffset.x))
    }

    private func getInfoWindowYOffset(annotationView: MKAnnotationView, annotation: FlutterAnnotation) -> CGFloat {
        return annotationView.frame.height * CGFloat(annotation.calloutOffset.y)
    }
}
