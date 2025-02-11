//
//  MapViewExtension.swift
//  apple_maps_flutter
//
//  Created by Luis Thein on 22.09.19.
//

import Foundation
import UIKit
import MapKit

public extension MKMapView {
    // keeps track of the Map values
    private struct Holder {
        static var _zoomLevel: Double = Double(0)
        static var _pitch: CGFloat = CGFloat(0)
        static var _heading: CLLocationDirection = CLLocationDirection(0)
        static var _maxZoomLevel: Double = Double(21)
        static var _minZoomLevel: Double = Double(2)
    }
    
    var maxZoomLevel: Double {
        set(_maxZoomLevel) {
            Holder._maxZoomLevel = _maxZoomLevel
            if Holder._zoomLevel > _maxZoomLevel {
                if #available(iOS 9.0, *) {
                    self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _maxZoomLevel, animated: false)
                } else {
                    self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: _maxZoomLevel, animated: false)
                }
            }
        }
        get {
            return Holder._maxZoomLevel
        }
    }
    
    var minZoomLevel: Double {
        set(_minZoomLevel) {
            Holder._minZoomLevel = _minZoomLevel
            if Holder._zoomLevel < _minZoomLevel {
                if #available(iOS 9.0, *) {
                   self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _minZoomLevel, animated: false)
                } else {
                   self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: _minZoomLevel, animated: false)
                }
            }
        }
        get {
           return Holder._minZoomLevel
        }
    }
    
    var zoomLevel: Double {
        get {
            return Holder._zoomLevel
        }
    }
    
    var calculatedZoomLevel: Double {
        get {
            // Calculate distance per pixel at zoom level 21
            let screenScale = UIScreen.main.scale  // To account for Retina screens
            let distancePerPixelAtZoom21 = MKMapView.mapWidthAtZoom21 / (256.0 * pow(2.0, maxZoomLevel)) / screenScale

            // Calculate zoom scale
            let zoomScale = (camera.altitude * tan(MKMapView.fieldOfViewAngle)) / distancePerPixelAtZoom21

            // Derive zoom level
            let zoomLevel = maxZoomLevel - log2(zoomScale)
            return zoomLevel
        }
        set (newZoomLevel) {
            Holder._zoomLevel = newZoomLevel
        }
    }
    
    func setCenterCoordinate(_ positionData: Dictionary<String, Any>, animated: Bool) {
        let targetList :Array<CLLocationDegrees> = positionData["target"] as? Array<CLLocationDegrees> ?? [self.camera.centerCoordinate.latitude, self.camera.centerCoordinate.longitude]
        let zoom :Double = positionData["zoom"] as? Double ?? Holder._zoomLevel
        Holder._zoomLevel = zoom
        if let pitch :CGFloat = positionData["pitch"] as? CGFloat {
            Holder._pitch = pitch
        }
        if let heading :CLLocationDirection = positionData["heading"] as? CLLocationDirection {
            Holder._heading = heading
        }
        let centerCoordinate :CLLocationCoordinate2D = CLLocationCoordinate2D(latitude:  targetList[0], longitude: targetList[1])
        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoom, animated: animated)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: zoom, animated: animated)
        }
    }
    
    func setBounds(_ positionData: Dictionary<String, Any>, animated: Bool) {
        guard let targetList :Array<Array<CLLocationDegrees>> = positionData["target"] as? Array<Array<CLLocationDegrees>> else { return }
        let padding :Double = positionData["padding"] as? Double ?? 0
        let coodinates: Array<CLLocationCoordinate2D> = targetList.map { (coordinate : Array<CLLocationDegrees>) in
            return CLLocationCoordinate2D(latitude:  coordinate[0], longitude: coordinate[1])
        }
        guard let mapRect = coodinates.mapRect() else { return }
        self.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsets(top: CGFloat(padding), left: CGFloat(padding), bottom: CGFloat(padding), right: CGFloat(padding)), animated: animated)
    }
    
    func setCenterCoordinateRegion(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);
    
        // use the zoom level to compute the region
        let span = self.coordinateSpanWithMapView(centerCoordinate: centerCoordinate, zoomLevel: Int(zoomL))
        let region = MKCoordinateRegion.init(center: centerCoordinate, span: span)
        
        // set the region like normal
        self.setRegion(region, animated: animated)
        
        // Setting the pitch/heading doesn't work while animating yet.
        // The animation will stop if the you change camera properties while it's running.
        if (!animated) {
            self.camera.pitch = Holder._pitch
            self.camera.heading = Holder._heading
        }
    }
    
    func coordinateSpanWithMapView(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Int) -> MKCoordinateSpan  {
        // convert center coordiate to pixel space
        let centerPixelX = Utils.longitudeToPixelSpaceX(longitude: centerCoordinate.longitude)
        let centerPixelY = Utils.latitudeToPixelSpaceY(latitude: centerCoordinate.latitude)
    
        // determine the scale value from the zoom level
        let zoomExponent = Double(21 - zoomLevel)
        let zoomScale = pow(2.0, zoomExponent)

        // scale the map’s size in pixel space
        let mapSizeInPixels = self.bounds.size
        let scaledMapWidth = Double(mapSizeInPixels.width) * zoomScale
        let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale;
    
        // figure out the position of the top-left pixel
        let topLeftPixelX = centerPixelX - (scaledMapWidth / 2);
        let topLeftPixelY = centerPixelY - (scaledMapHeight / 2);
    
        // find delta between left and right longitudes
        let minLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX)
        let maxLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX + scaledMapWidth)
        let longitudeDelta = maxLng - minLng;
    
        // find delta between top and bottom latitudes
        let minLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY)
        let maxLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY + scaledMapHeight)
        let latitudeDelta = -1 * (maxLat - minLat)
    
        // create and return the lat/lng span
        return MKCoordinateSpan.init(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    }
    
    @available(iOS 9.0, *)
    func setCenterCoordinateWithAltitude(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);
        let altitude = getCameraAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoomL)
        self.setCamera(MKMapCamera(lookingAtCenter: centerCoordinate, fromDistance: CLLocationDistance(altitude), pitch: Holder._pitch, heading: Holder._heading), animated: animated)
    }
    
    static let earthCircumference: Double = 40_075_016.686  // Earth's circumference in meters
    static let mapWidthAtZoom21: Double = earthCircumference / 2.0  // Half circumference at zoom level 21
    static let fieldOfViewAngle: Double = 15.0 * .pi / 180.0  // Field of view in radians
    private func getCameraAltitude(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double) -> Double {
        // Calculate distance per pixel at zoom level 21
        let screenScale = UIScreen.main.scale  // To account for Retina screens
        let distancePerPixelAtZoom21 = MKMapView.mapWidthAtZoom21 / (256.0 * pow(2.0, maxZoomLevel)) / screenScale

        // Calculate zoom scale
        let zoomScale = pow(2.0, maxZoomLevel - zoomLevel)

        // Derive altitude
        let altitude = (distancePerPixelAtZoom21 * zoomScale) / tan(MKMapView.fieldOfViewAngle)
        return altitude
    }
    
    func getVisibleRegion() -> Dictionary<String, Array<Double>> {
        if self.bounds.size != CGSize.zero {
            // convert center coordiate to pixel space
            let centerPixelX = Utils.longitudeToPixelSpaceX(longitude: self.centerCoordinate.longitude)
            let centerPixelY = Utils.latitudeToPixelSpaceY(latitude: self.centerCoordinate.latitude)

            // determine the scale value from the zoom level
            let zoomExponent = Double(21 - Holder._zoomLevel)
            let zoomScale = pow(2.0, zoomExponent)

            // scale the map’s size in pixel space
            let mapSizeInPixels = self.bounds.size
            let scaledMapWidth = Double(mapSizeInPixels.width) * zoomScale
            let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale;

            // figure out the position of the top-left pixel
            let topLeftPixelX = centerPixelX - (scaledMapWidth / 2);
            let topLeftPixelY = centerPixelY - (scaledMapHeight / 2);

            // find the southwest coordinate
            let minLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX)
            let minLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY)

            // find the northeast coordinate
            let maxLng = Utils.pixelSpaceXToLongitude(pixelX: topLeftPixelX + scaledMapWidth)
            let maxLat = Utils.pixelSpaceYToLatitude(pixelY: topLeftPixelY + scaledMapHeight)

            return ["northeast": [minLat, maxLng], "southwest": [maxLat, minLng]]
        }
        return ["northeast": [0.0, 0.0], "southwest": [0.0, 0.0]]
    }
    
    func zoomIn(animated: Bool) {
        if Holder._zoomLevel - 1 <= Holder._maxZoomLevel {
            if Holder._zoomLevel < 2 {
                Holder._zoomLevel = 2
            }
            Holder._zoomLevel += 1
            if #available(iOS 9.0, *) {
                self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
            } else {
                self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
            }
        }
    }
    
    func zoomOut(animated: Bool) {
        if Holder._zoomLevel - 1 >= Holder._minZoomLevel {
            Holder._zoomLevel -= 1
            if round(Holder._zoomLevel) <= 2 {
               Holder._zoomLevel = 0
            }

            if #available(iOS 9.0, *) {
               self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
            } else {
               self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
            }
        }
    }
    
    func zoomTo(newZoomLevel: Double, animated: Bool) {
        if newZoomLevel < Holder._minZoomLevel {
            Holder._zoomLevel = Holder._minZoomLevel
        } else if newZoomLevel > Holder._maxZoomLevel {
            Holder._zoomLevel = Holder._maxZoomLevel
        } else {
            Holder._zoomLevel = newZoomLevel
        }

        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
        }
    }
    
    func zoomBy(zoomBy: Double, animated: Bool) {
        if Holder._zoomLevel + zoomBy < Holder._minZoomLevel {
            Holder._zoomLevel = Holder._minZoomLevel
        } else if Holder._zoomLevel + zoomBy > Holder._maxZoomLevel {
            Holder._zoomLevel = Holder._maxZoomLevel
        } else {
            Holder._zoomLevel = Holder._zoomLevel + zoomBy
        }
        
        if #available(iOS 9.0, *) {
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
        } else {
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
        }
    }
    
    func updateStoredCameraValues(newZoomLevel: Double, newPitch: CGFloat, newHeading: CLLocationDirection) {
        Holder._zoomLevel = newZoomLevel
        Holder._pitch = newPitch
        Holder._heading = newHeading
    }
}

extension Array where Element == CLLocationCoordinate2D {
    func mapRect() -> MKMapRect? {
        return map(MKMapPoint.init).mapRect()
    }
}

extension Array where Element == CLLocation {
    func mapRect() -> MKMapRect? {
        return map { MKMapPoint($0.coordinate) }.mapRect()
    }
}

extension Array where Element == MKMapPoint {
    func mapRect() -> MKMapRect? {
        guard count > 0 else { return nil }

        let xs = map { $0.x }
        let ys = map { $0.y }

        let west = xs.min()!
        let east = xs.max()!
        let width = east - west

        let south = ys.min()!
        let north = ys.max()!
        let height = north - south

        return MKMapRect(x: west, y: south, width: width, height: height)
    }
}
