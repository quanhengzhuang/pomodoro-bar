import SceneKit
import SwiftUI
import UIKit
import simd

struct DiceSceneView: UIViewRepresentable {
    let diceCount: Int
    let rollToken: Int
    let reduceMotion: Bool
    let accessibilityValue: String
    let onRollFinished: ([Int]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero)
        sceneView.scene = context.coordinator.scene
        sceneView.delegate = context.coordinator
        sceneView.backgroundColor = .clear
        sceneView.antialiasingMode = .multisampling4X
        sceneView.preferredFramesPerSecond = 60
        sceneView.isPlaying = true
        sceneView.rendersContinuously = true
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        sceneView.isAccessibilityElement = true
        sceneView.accessibilityLabel = "3D 骰盘"
        sceneView.accessibilityValue = accessibilityValue

        context.coordinator.sceneView = sceneView
        context.coordinator.lastRollToken = rollToken
        context.coordinator.ensureDice(count: diceCount)
        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        context.coordinator.parent = self
        sceneView.accessibilityValue = accessibilityValue

        if !context.coordinator.isRolling {
            context.coordinator.ensureDice(count: diceCount)
        }

        guard context.coordinator.lastRollToken != rollToken else { return }
        context.coordinator.lastRollToken = rollToken
        context.coordinator.roll(count: diceCount, reduceMotion: reduceMotion)
    }

    static func dismantleUIView(_ sceneView: SCNView, coordinator: Coordinator) {
        sceneView.delegate = nil
        sceneView.isPlaying = false
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: DiceSceneView
        let scene = SCNScene()
        weak var sceneView: SCNView?

        var lastRollToken = 0
        var isRolling = false

        private var dice: [SCNNode] = []
        private var dieSize: CGFloat = 1.08
        private var rollStartedAt: CFTimeInterval = 0
        private var settledFrameCount = 0
        private var faceImageCache: [Int: UIImage] = [:]

        init(parent: DiceSceneView) {
            self.parent = parent
            super.init()
            configureScene()
        }

        func ensureDice(count: Int) {
            let clampedCount = min(max(count, 1), 10)
            guard dice.count != clampedCount else { return }

            dice.forEach { $0.removeFromParentNode() }
            dieSize = clampedCount <= 5 ? 1.32 : 0.90
            dice = (0..<clampedCount).map { index in
                let die = makeDie(size: dieSize)
                die.name = "die-\(index)"
                scene.rootNode.addChildNode(die)
                return die
            }
            layoutDice()
        }

        func roll(count: Int, reduceMotion: Bool) {
            ensureDice(count: count)
            guard !isRolling else { return }

            if reduceMotion {
                performReducedMotionRoll()
                return
            }

            isRolling = true
            settledFrameCount = 0
            rollStartedAt = CACurrentMediaTime()

            for (index, die) in dice.enumerated() {
                guard let body = die.physicsBody else { continue }
                body.type = .dynamic
                body.clearAllForces()
                body.velocity = SCNVector3Zero
                body.angularVelocity = SCNVector4Zero

                let column = Float(index % 5) - Float(min(dice.count, 5) - 1) / 2
                let row = Float(index / 5)
                die.position = SCNVector3(
                    column * Float(dieSize * 1.32),
                    1.05 + row * Float(dieSize * 1.25),
                    1.65 + row * 0.18
                )
                die.simdOrientation = randomOrientation()
                body.resetTransform()

                body.velocity = SCNVector3(
                    Float.random(in: -1.25...1.25),
                    Float.random(in: 2.4...3.8),
                    Float.random(in: -3.8 ... -2.3)
                )
                let spinAxis = randomUnitVector()
                body.angularVelocity = SCNVector4(
                    spinAxis.x,
                    spinAxis.y,
                    spinAxis.z,
                    Float.random(in: 10...17)
                )
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard isRolling else { return }

            let elapsed = CACurrentMediaTime() - rollStartedAt
            guard elapsed > 0.75 else { return }

            let allSettled = dice.allSatisfy { die in
                guard let body = die.physicsBody else { return true }
                return body.isResting || (body.velocity.length < 0.12 && abs(body.angularVelocity.w) < 0.22)
            }

            keepDiceInsideTray()

            settledFrameCount = allSettled ? settledFrameCount + 1 : 0
            if settledFrameCount >= 16 || elapsed > 4.6 {
                completePhysicalRoll()
            }
        }

        private func configureScene() {
            scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
            scene.background.contents = UIColor.clear

            let cameraTarget = SCNNode()
            cameraTarget.position = SCNVector3(0, 0, -0.35)
            scene.rootNode.addChildNode(cameraTarget)

            let cameraNode = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 43
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = true
            camera.exposureOffset = -0.15
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 9.6, 7.7)
            let lookAt = SCNLookAtConstraint(target: cameraTarget)
            lookAt.isGimbalLockEnabled = true
            cameraNode.constraints = [lookAt]
            scene.rootNode.addChildNode(cameraNode)

            let keyLightNode = SCNNode()
            let keyLight = SCNLight()
            keyLight.type = .omni
            keyLight.intensity = 1_150
            keyLight.temperature = 3_800
            keyLight.castsShadow = true
            keyLight.shadowRadius = 7
            keyLight.shadowColor = UIColor.black.withAlphaComponent(0.62)
            keyLightNode.light = keyLight
            keyLightNode.position = SCNVector3(-3.6, 7.4, 5.2)
            scene.rootNode.addChildNode(keyLightNode)

            let fillLightNode = SCNNode()
            let fillLight = SCNLight()
            fillLight.type = .omni
            fillLight.intensity = 410
            fillLight.temperature = 6_800
            fillLightNode.light = fillLight
            fillLightNode.position = SCNVector3(4.5, 4.0, -4.0)
            scene.rootNode.addChildNode(fillLightNode)

            let ambientNode = SCNNode()
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 230
            ambient.color = UIColor(red: 0.36, green: 0.48, blue: 0.41, alpha: 1)
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            addTray()
        }

        private func addTray() {
            let floor = SCNBox(width: 10.0, height: 0.34, length: 7.0, chamferRadius: 0.38)
            floor.materials = [feltMaterial()]
            let floorNode = SCNNode(geometry: floor)
            floorNode.position = SCNVector3(0, -0.42, 0)
            floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: floor, options: nil))
            floorNode.physicsBody?.friction = 0.86
            floorNode.physicsBody?.restitution = 0.27
            scene.rootNode.addChildNode(floorNode)

            // An infinite, invisible safety surface prevents a fast-moving die from tunnelling
            // through the decorative floor on older devices.
            let safetyFloor = SCNFloor()
            safetyFloor.reflectivity = 0
            let safetyFloorNode = SCNNode(geometry: safetyFloor)
            safetyFloorNode.opacity = 0.001
            safetyFloorNode.position = SCNVector3(0, -0.235, 0)
            safetyFloorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            safetyFloorNode.physicsBody?.friction = 0.86
            safetyFloorNode.physicsBody?.restitution = 0.27
            scene.rootNode.addChildNode(safetyFloorNode)

            let visibleWalls: [(SCNVector3, SCNVector3)] = [
                (SCNVector3(0, 0.12, -3.58), SCNVector3(10.4, 0.9, 0.42)),
                (SCNVector3(0, 0.12, 3.58), SCNVector3(10.4, 0.9, 0.42)),
                (SCNVector3(-5.18, 0.12, 0), SCNVector3(0.42, 0.9, 7.5)),
                (SCNVector3(5.18, 0.12, 0), SCNVector3(0.42, 0.9, 7.5))
            ]

            for (position, size) in visibleWalls {
                let wall = SCNBox(
                    width: CGFloat(size.x),
                    height: CGFloat(size.y),
                    length: CGFloat(size.z),
                    chamferRadius: 0.16
                )
                wall.materials = [walnutMaterial()]
                let node = SCNNode(geometry: wall)
                node.position = position
                node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: wall, options: nil))
                node.physicsBody?.friction = 0.7
                node.physicsBody?.restitution = 0.36
                scene.rootNode.addChildNode(node)
            }

            let collisionWalls: [(SCNVector3, SCNVector3)] = [
                (SCNVector3(0, 2.75, -3.72), SCNVector3(10.6, 6.0, 0.18)),
                (SCNVector3(0, 2.75, 3.72), SCNVector3(10.6, 6.0, 0.18)),
                (SCNVector3(-5.30, 2.75, 0), SCNVector3(0.18, 6.0, 7.6)),
                (SCNVector3(5.30, 2.75, 0), SCNVector3(0.18, 6.0, 7.6))
            ]

            for (position, size) in collisionWalls {
                let wall = SCNBox(
                    width: CGFloat(size.x),
                    height: CGFloat(size.y),
                    length: CGFloat(size.z),
                    chamferRadius: 0
                )
                let node = SCNNode(geometry: wall)
                node.opacity = 0
                node.position = position
                node.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: wall, options: nil))
                node.physicsBody?.friction = 0.58
                node.physicsBody?.restitution = 0.42
                scene.rootNode.addChildNode(node)
            }
        }

        private func makeDie(size: CGFloat) -> SCNNode {
            let box = SCNBox(width: size, height: size, length: size, chamferRadius: size * 0.15)
            // SCNBox material order: front, right, back, left, top, bottom.
            box.materials = [2, 3, 5, 4, 1, 6].map(dieMaterial(face:))

            let node = SCNNode(geometry: box)
            let shape = SCNPhysicsShape(
                geometry: box,
                options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.convexHull]
            )
            let body = SCNPhysicsBody(type: .kinematic, shape: shape)
            body.mass = 0.18
            body.friction = 0.76
            body.rollingFriction = 0.24
            body.restitution = 0.38
            body.damping = 0.18
            body.angularDamping = 0.22
            body.continuousCollisionDetectionThreshold = 0.08
            node.physicsBody = body
            return node
        }

        private func layoutDice() {
            let columns = min(dice.count, 5)
            let rows = dice.count > 5 ? 2 : 1
            let spacing = dieSize * 1.47
            let floorTop: CGFloat = -0.25

            for (index, die) in dice.enumerated() {
                let row = index / columns
                let itemsInRow = row == rows - 1 ? dice.count - row * columns : columns
                let column = index % columns
                let x = (CGFloat(column) - CGFloat(itemsInRow - 1) / 2) * spacing
                let z = rows == 1 ? CGFloat.zero : (CGFloat(row) - 0.5) * spacing
                die.position = SCNVector3(Float(x), Float(floorTop + dieSize / 2 + 0.025), Float(z))
                die.simdOrientation = orientation(showing: (index % 6) + 1, yaw: Float(index) * 0.31)
                die.physicsBody?.type = .kinematic
                die.physicsBody?.resetTransform()
            }
        }

        private func performReducedMotionRoll() {
            isRolling = true
            let values = dice.map { _ in Int.random(in: 1...6) }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.16
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            for (index, die) in dice.enumerated() {
                die.simdOrientation = orientation(showing: values[index], yaw: Float.random(in: 0...(2 * .pi)))
            }
            SCNTransaction.completionBlock = { [weak self] in
                guard let self else { return }
                self.isRolling = false
                DispatchQueue.main.async {
                    self.parent.onRollFinished(values)
                }
            }
            SCNTransaction.commit()
        }

        private func completePhysicalRoll() {
            guard isRolling else { return }
            isRolling = false

            let values = dice.map { die in
                isInsideTray(die.presentation.position) ? topFaceValue(of: die) : Int.random(in: 1...6)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.presentFinalValues(values) {
                    self.parent.onRollFinished(values)
                }
            }
        }

        private func presentFinalValues(_ values: [Int], completion: @escaping () -> Void) {
            let columns = min(dice.count, 5)
            let rows = dice.count > 5 ? 2 : 1
            let spacing = dieSize * 1.47
            let floorTop: CGFloat = -0.25

            for die in dice {
                die.physicsBody?.type = .kinematic
                die.physicsBody?.clearAllForces()
            }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            SCNTransaction.completionBlock = completion
            for (index, die) in dice.enumerated() {
                let row = index / columns
                let itemsInRow = row == rows - 1 ? dice.count - row * columns : columns
                let column = index % columns
                let x = (CGFloat(column) - CGFloat(itemsInRow - 1) / 2) * spacing
                let z = rows == 1 ? CGFloat.zero : (CGFloat(row) - 0.5) * spacing
                die.position = SCNVector3(Float(x), Float(floorTop + dieSize / 2 + 0.025), Float(z))
                die.simdOrientation = orientation(showing: values[index], yaw: Float.random(in: 0...(2 * .pi)))
                die.physicsBody?.resetTransform()
            }
            SCNTransaction.commit()
        }

        private func keepDiceInsideTray() {
            for die in dice where !isInsideTray(die.presentation.position) {
                guard let body = die.physicsBody else { continue }
                body.type = .kinematic
                body.clearAllForces()
                die.position = SCNVector3(
                    Float.random(in: -2.4...2.4),
                    1.2,
                    Float.random(in: -1.4...1.4)
                )
                die.simdOrientation = randomOrientation()
                body.resetTransform()
                body.type = .dynamic
                body.velocity = SCNVector3(
                    Float.random(in: -0.7...0.7),
                    Float.random(in: 0.8...1.5),
                    Float.random(in: -1.0...1.0)
                )
                let spinAxis = randomUnitVector()
                body.angularVelocity = SCNVector4(spinAxis.x, spinAxis.y, spinAxis.z, Float.random(in: 6...11))
            }
        }

        private func isInsideTray(_ position: SCNVector3) -> Bool {
            position.x.isFinite
                && position.y.isFinite
                && position.z.isFinite
                && abs(position.x) < 4.75
                && position.y > -0.42
                && position.y < 5.6
                && abs(position.z) < 3.25
        }

        private func topFaceValue(of die: SCNNode) -> Int {
            let transform = die.presentation.simdWorldTransform
            let faces: [(value: Int, normal: SIMD3<Float>)] = [
                (1, SIMD3(0, 1, 0)),
                (6, SIMD3(0, -1, 0)),
                (2, SIMD3(0, 0, 1)),
                (5, SIMD3(0, 0, -1)),
                (3, SIMD3(1, 0, 0)),
                (4, SIMD3(-1, 0, 0))
            ]

            return faces.max { lhs, rhs in
                worldY(of: lhs.normal, using: transform) < worldY(of: rhs.normal, using: transform)
            }?.value ?? 1
        }

        private func worldY(of normal: SIMD3<Float>, using transform: simd_float4x4) -> Float {
            transform.columns.0.y * normal.x
                + transform.columns.1.y * normal.y
                + transform.columns.2.y * normal.z
        }

        private func orientation(showing value: Int, yaw: Float) -> simd_quatf {
            let alignment: simd_quatf
            switch value {
            case 2:
                alignment = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
            case 3:
                alignment = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
            case 4:
                alignment = simd_quatf(angle: -.pi / 2, axis: SIMD3(0, 0, 1))
            case 5:
                alignment = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
            case 6:
                alignment = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
            default:
                alignment = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
            }
            return simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)) * alignment
        }

        private func randomOrientation() -> simd_quatf {
            simd_quatf(angle: Float.random(in: 0...(2 * .pi)), axis: randomUnitVector())
        }

        private func randomUnitVector() -> SIMD3<Float> {
            var vector = SIMD3<Float>(
                Float.random(in: -1...1),
                Float.random(in: -1...1),
                Float.random(in: -1...1)
            )
            if simd_length_squared(vector) < 0.01 {
                vector = SIMD3(0.4, 0.8, 0.2)
            }
            return simd_normalize(vector)
        }

        private func dieMaterial(face: Int) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = faceImage(face)
            material.diffuse.mipFilter = .linear
            material.roughness.contents = 0.64
            material.metalness.contents = 0.0
            return material
        }

        private func feltMaterial() -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = UIColor(red: 0.055, green: 0.20, blue: 0.16, alpha: 1)
            material.roughness.contents = 0.94
            material.metalness.contents = 0.0
            return material
        }

        private func walnutMaterial() -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = UIColor(red: 0.27, green: 0.115, blue: 0.055, alpha: 1)
            material.roughness.contents = 0.58
            material.metalness.contents = 0.0
            return material
        }

        private func faceImage(_ face: Int) -> UIImage {
            if let cached = faceImageCache[face] { return cached }

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
            let image = renderer.image { context in
                let bounds = CGRect(x: 0, y: 0, width: 256, height: 256)
                UIColor(red: 0.96, green: 0.925, blue: 0.82, alpha: 1).setFill()
                context.fill(bounds)

                let points = pipPositions(for: face)
                for point in points {
                    let rect = CGRect(x: point.x - 20, y: point.y - 20, width: 40, height: 40)
                    context.cgContext.saveGState()
                    context.cgContext.setShadow(
                        offset: CGSize(width: 2.5, height: 3.5),
                        blur: 4,
                        color: UIColor.black.withAlphaComponent(0.42).cgColor
                    )
                    UIColor(red: 0.075, green: 0.065, blue: 0.055, alpha: 1).setFill()
                    context.cgContext.fillEllipse(in: rect)
                    context.cgContext.restoreGState()

                    UIColor.white.withAlphaComponent(0.14).setFill()
                    context.cgContext.fillEllipse(in: CGRect(x: rect.minX + 8, y: rect.minY + 7, width: 9, height: 7))
                }
            }
            faceImageCache[face] = image
            return image
        }

        private func pipPositions(for face: Int) -> [CGPoint] {
            let low: CGFloat = 68
            let mid: CGFloat = 128
            let high: CGFloat = 188

            switch face {
            case 1: return [CGPoint(x: mid, y: mid)]
            case 2: return [CGPoint(x: low, y: low), CGPoint(x: high, y: high)]
            case 3: return [CGPoint(x: low, y: low), CGPoint(x: mid, y: mid), CGPoint(x: high, y: high)]
            case 4:
                return [CGPoint(x: low, y: low), CGPoint(x: high, y: low), CGPoint(x: low, y: high), CGPoint(x: high, y: high)]
            case 5:
                return [CGPoint(x: low, y: low), CGPoint(x: high, y: low), CGPoint(x: mid, y: mid), CGPoint(x: low, y: high), CGPoint(x: high, y: high)]
            default:
                return [CGPoint(x: low, y: low), CGPoint(x: high, y: low), CGPoint(x: low, y: mid), CGPoint(x: high, y: mid), CGPoint(x: low, y: high), CGPoint(x: high, y: high)]
            }
        }
    }
}

private extension SCNVector3 {
    var length: Float {
        sqrt(x * x + y * y + z * z)
    }
}
