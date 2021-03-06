// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2012 Steve Nygard.

#import "CDClassDumpVisitor.h"

#include <mach-o/arch.h>

#import "CDClassDump.h"
#import "CDObjectiveCProcessor.h"
#import "CDMachOFile.h"
#import "CDLCDylib.h"
#import "CDLCDylinker.h"
#import "CDLCEncryptionInfo.h"
#import "CDLCRunPath.h"
#import "CDLCSegment.h"
#import "CDLCVersionMinimum.h"
#import "CDTypeController.h"

@implementation CDClassDumpVisitor
{
}

- (void)willBeginVisiting;
{
    [super willBeginVisiting];

    [self.classDump appendHeaderToString:self.resultString];

    if (self.classDump.hasObjectiveCRuntimeInfo) {
        [self.classDump.typeController appendStructuresToString:self.resultString];
    }
}

- (void)didEndVisiting;
{
    [super didEndVisiting];

    [self writeResultToStandardOutput];
}

- (void)visitObjectiveCProcessor:(CDObjectiveCProcessor *)processor;
{
    CDMachOFile *machOFile = processor.machOFile;

    [self.resultString appendString:@"#pragma mark -\n\n"];
    [self.resultString appendString:@"/*\n"];
    [self.resultString appendFormat:@" * File: %@\n", machOFile.filename];
    [self.resultString appendFormat:@" * UUID: %@\n", machOFile.uuidString];

    const NXArchInfo *archInfo = NXGetArchInfoFromCpuType(machOFile.cputypePlusArchBits, machOFile.cpusubtype);
    if (archInfo == NULL)
        [self.resultString appendFormat:@" * Arch: cputype: 0x%x, cpusubtype: 0x%x\n", machOFile.cputype, machOFile.cpusubtype];
    else
        [self.resultString appendFormat:@" * Arch: %s (%s)\n", archInfo->description, archInfo->name];

    if (machOFile.filetype == MH_DYLIB) {
        CDLCDylib *identifier = machOFile.dylibIdentifier;
        if (identifier != nil)
            [self.resultString appendFormat:@" *       Current version: %@, Compatibility version: %@\n",
             identifier.formattedCurrentVersion, identifier.formattedCompatibilityVersion];
    }

    if (machOFile.minVersionMacOSX != nil) 
        [self.resultString appendFormat:@" *       Minimum Mac OS X version: %@\n", machOFile.minVersionMacOSX.minimumVersionString];
    if (machOFile.minVersionIOS != nil) 
        [self.resultString appendFormat:@" *       Minimum iOS version: %@\n", machOFile.minVersionIOS.minimumVersionString];

    [self.resultString appendFormat:@" *\n"];
    if (processor.garbageCollectionStatus != nil)
        [self.resultString appendFormat:@" *       Objective-C Garbage Collection: %@\n", processor.garbageCollectionStatus];

    [machOFile.dyldEnvironment enumerateObjectsUsingBlock:^(CDLCDylinker *env, NSUInteger index, BOOL *stop){
        if (index == 0) {
            [self.resultString appendFormat:@" *       dyld environment: %@\n", env.name];
        } else {
            [self.resultString appendFormat:@" *                         %@\n", env.name];
        }
    }];

    for (CDLoadCommand *loadCommand in machOFile.loadCommands) {
        if ([loadCommand isKindOfClass:[CDLCRunPath class]]) {
            CDLCRunPath *runPath = (CDLCRunPath *)loadCommand;

            [self.resultString appendFormat:@" *       Run path: %@\n", runPath.path];
            [self.resultString appendFormat:@" *               = %@\n", runPath.resolvedRunPath];
        }
    }

    if (machOFile.isEncrypted) {
        [self.resultString appendString:@" *       This file is encrypted:\n"];
        for (CDLoadCommand *loadCommand in machOFile.loadCommands) {
            if ([loadCommand isKindOfClass:[CDLCEncryptionInfo class]]) {
                CDLCEncryptionInfo *encryptionInfo = (CDLCEncryptionInfo *)loadCommand;

                [self.resultString appendFormat:@" *           cryptid: 0x%08x, cryptoff: 0x%08x, cryptsize: 0x%08x\n",
                 encryptionInfo.cryptid, encryptionInfo.cryptoff, encryptionInfo.cryptsize];
            }
        }
    } else if (machOFile.hasProtectedSegments) {
        if (machOFile.canDecryptAllSegments) {
            [self.resultString appendString:@" *       This file has protected segments, decrypting.\n"];
        } else {
            [self.resultString appendString:@" *       This file has protected segments that can't be decrypted:\n"];
            [machOFile.loadCommands enumerateObjectsUsingBlock:^(CDLoadCommand *loadCommand, NSUInteger index, BOOL *stop){
                if ([loadCommand isKindOfClass:[CDLCSegment class]]) {
                    CDLCSegment *segment = (CDLCSegment *)loadCommand;
                    
                    if (segment.canDecrypt == NO) {
                        [self.resultString appendFormat:@" *           Load command %u, segment encryption: %@\n",
                         index, CDSegmentEncryptionTypeName(segment.encryptionType)];
                    }
                }
            }];
        }
    }
    [self.resultString appendString:@" */\n\n"];
    
    if (!self.classDump.hasObjectiveCRuntimeInfo) {
        [self.resultString appendString:@"//\n"];
        [self.resultString appendString:@"// This file does not contain any Objective-C runtime information.\n"];
        [self.resultString appendString:@"//\n"];
    }
}

@end
