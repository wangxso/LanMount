//
//  LanMount-Bridging-Header.h
//  LanMount
//
//  Bridging header for importing C frameworks into Swift
//

#ifndef LanMount_Bridging_Header_h
#define LanMount_Bridging_Header_h

// NetFS framework for SMB mounting operations
#import <NetFS/NetFS.h>

// System headers for unmount operations
#include <sys/mount.h>

#endif /* LanMount_Bridging_Header_h */
