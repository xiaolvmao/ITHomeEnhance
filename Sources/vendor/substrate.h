//
//  substrate.h —— 极简 hook 层声明
//
//  TrollStore 环境没有 CydiaSubstrate / ElleKit 可用，这里声明同名符号，
//  由 ITXSubstrate.m 用 ObjC runtime 自带实现补齐，Logos 生成的代码即可直接链接。
//
#ifndef ITX_SUBSTRATE_H
#define ITX_SUBSTRATE_H

#import <objc/runtime.h>
#import <objc/message.h>

#ifdef __cplusplus
extern "C" {
#endif

void MSHookMessageEx(Class _class, SEL sel, IMP replacement, IMP *result);
void *MSHookFunction(void *symbol, void *replace, void **result);

#ifdef __cplusplus
}
#endif

#endif
