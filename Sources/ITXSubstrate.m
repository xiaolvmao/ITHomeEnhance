//
//  ITXSubstrate.m
//  IT之家增强
//
//  替代 CydiaSubstrate 的最小实现。
//  TrollStore 环境下没有注入式 hook 库，但本项目所有 hook 目标都是 ObjC 方法，
//  用 runtime 的 class_replaceMethod 即可完成等价工作，Logos 语法照常使用。
//

#import "vendor/substrate.h"
#import "ITXLog.h"

static void ITXReplaceMethod(Class cls, SEL sel, IMP replacement, IMP *result) {
    if (result) *result = NULL;
    if (!cls || !sel || !replacement) return;

    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        ITXLog(@"[hook] 方法不存在：%@ -%s", NSStringFromClass(cls), sel_getName(sel));
        return;
    }

    IMP original = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);

    // 保留原实现给 %orig 使用
    if (result) *result = original;

    if (class_addMethod(cls, sel, replacement, types)) {
        // 方法继承自父类：已在本类补上替身，父类实现仍由 %orig 调用
    } else {
        class_replaceMethod(cls, sel, replacement, types);
    }
}

void MSHookMessageEx(Class _class, SEL sel, IMP replacement, IMP *result) {
    ITXReplaceMethod(_class, sel, replacement, result);
}

void *MSHookFunction(void *symbol, void *replace, void **result) {
    // 本项目不使用 %hookf，占位以满足链接
    if (result) *result = symbol;
    return symbol;
}
