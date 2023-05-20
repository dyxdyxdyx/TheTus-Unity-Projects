using UnityEngine;

public class CameraController : MonoBehaviour{
    public Transform target; // 旋转的目标物体
    public float distance = 1f; // 摄像机与目标物体的距离
    public Vector2 rotationSpeed = new Vector2(0.1f, 0.1f); // 摄像机旋转速度
    public float zoomSpeed = 1f; // 摄像机缩放速度
    public float zoomMin = 1f; // 摄像机缩放最小值
    public float zoomMax = 10f; // 摄像机缩放最大值


    private Quaternion originalRot;
    private Vector3 lastMousePosition; // 上一帧的鼠标位置

    void Start() {
        originalRot = transform.rotation;
    }

    void Update() {
        UpdateCameraByMouse();
        UpdateCameraByKeyboard();
    }

    void UpdateCameraByMouse() {
        // 旋转摄像机
        if (Input.GetMouseButton(0)) // 如果鼠标左键被按下
        {
            Vector3 mouseDelta = (Input.mousePosition - lastMousePosition); // 计算鼠标移动的增量
            float rotationY = -mouseDelta.x * rotationSpeed.x * Time.deltaTime; // 计算绕Y轴旋转的角度
            transform.RotateAround(target.position, Vector3.up, rotationY); // 绕目标物体的Y轴旋转
        }

        if (Input.GetMouseButton(1)) {
            Vector3 mouseDelta = Input.mousePosition - lastMousePosition; // 计算鼠标移动的增量
            float rotationX = -mouseDelta.y * rotationSpeed.y * Time.deltaTime; // 计算绕X轴旋转的角度
            transform.RotateAround(target.position, Vector3.right, rotationX); // 绕目标物体的X轴旋转
        }

        lastMousePosition = Input.mousePosition; // 更新上一帧的鼠标位置

        // 缩放摄像机
        float zoomDelta = Input.GetAxis("Mouse ScrollWheel") * zoomSpeed * Time.deltaTime; // 计算鼠标滚轮滑动的增量
        float zoomValue = Mathf.Clamp(distance - zoomDelta, zoomMin, zoomMax); // 计算缩放后的距离
        distance = zoomValue;
        transform.position = target.position - transform.forward * distance; // 更新摄像机位置
    }

    void UpdateCameraByKeyboard() {
        bool isUp = (Input.GetKey(KeyCode.UpArrow) && !Input.GetKey(KeyCode.DownArrow)) || (Input.GetKey(KeyCode.W) && !Input.GetKey(KeyCode.S)),
            isDown = (Input.GetKey(KeyCode.DownArrow) && !Input.GetKey(KeyCode.UpArrow)) || (Input.GetKey(KeyCode.S) && !Input.GetKey(KeyCode.W)),
            isLeft = (Input.GetKey(KeyCode.LeftArrow) && !Input.GetKey(KeyCode.RightArrow)) || (Input.GetKey(KeyCode.A) && !Input.GetKey(KeyCode.D)),
            isRight = (Input.GetKey(KeyCode.RightArrow) && !Input.GetKey(KeyCode.LeftArrow)) || (Input.GetKey(KeyCode.D) && !Input.GetKey(KeyCode.A));

        float rotationX = -(isUp ? 1 : isDown ? -1 : 0) * rotationSpeed.y * Time.deltaTime; // 计算绕X轴旋转的角度
        float rotationY = -(isLeft ? 1 : isRight ? -1 : 0) * rotationSpeed.x * Time.deltaTime; // 计算绕Y轴旋转的角度
        transform.RotateAround(target.position, Vector3.right, rotationX); // 绕目标物体的X轴旋转
        transform.RotateAround(target.position, Vector3.up, rotationY); // 绕目标物体的Y轴旋转

        if (Input.GetKeyDown(KeyCode.R)) transform.rotation = originalRot;
    }
}