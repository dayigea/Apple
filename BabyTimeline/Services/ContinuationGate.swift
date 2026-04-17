import Foundation

/// 线程安全的"只允许一次"守门器，用来保证 `withCheckedContinuation` 里的
/// continuation **最多被 resume 一次**。
///
/// 使用场景：Vision / PhotosKit 的同步 API 带回调，有时会既触发回调又抛异常；
/// 或者回调被底层在多线程并发触发。直接用 `var didResume = false` 做去重
/// 在并发下不安全，会导致 double-resume → undefined behavior → EXC_BAD_ACCESS。
///
/// 用法：
/// ```swift
/// await withCheckedContinuation { continuation in
///     let gate = ContinuationGate()
///     someAPI { result in
///         if gate.open() { continuation.resume(returning: result) }
///     }
///     // 兜底路径
///     if gate.open() { continuation.resume(returning: fallback) }
/// }
/// ```
/// `open()` 第一次调用返回 `true` 并"开一次门"，之后所有调用都返回 `false`。
final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var opened = false

    /// 第一次调用返回 true，此时调用方应该 resume 对应的 continuation；
    /// 之后所有调用返回 false，调用方什么都不要做。
    func open() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if opened { return false }
        opened = true
        return true
    }
}
