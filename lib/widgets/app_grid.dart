import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vaxp_core/models/desktop_entry.dart';

const double _kDotSize = 8.0;
const double _kDotSpacing = 8.0;

class AppGrid extends StatefulWidget {
  final List<DesktopEntry> apps;
  final String? iconThemeDir;
  final void Function(DesktopEntry) onLaunch;
  final void Function(DesktopEntry)? onPin;
  final void Function(DesktopEntry)? onInstall;
  final void Function(DesktopEntry)? onCreateShortcut;
  final void Function(DesktopEntry)? onLaunchWithExternalGPU;

  const AppGrid({
    super.key,
    required this.apps,
    required this.onLaunch,
    this.iconThemeDir,
    this.onPin,
    this.onInstall,
    this.onCreateShortcut,
    this.onLaunchWithExternalGPU,
  });

  @override
  State<AppGrid> createState() => _AppGridState();
}

class _AppGridState extends State<AppGrid> {
  static const int itemsPerPage = 24;
  int _currentPage = 0;
  List<File> _themeFiles = [];
  late int _totalPages;
  final PageController _pageController = PageController();
  bool _isScrolling = false;
  DateTime _lastScrollTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadThemeFiles();
    _updateTotalPages();
  }

  void _updateTotalPages() {
    _totalPages = math.max(1, (widget.apps.length / itemsPerPage).ceil());
  }

  @override
  void didUpdateWidget(AppGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apps.length != oldWidget.apps.length) {
      _updateTotalPages();
      // Ensure current page is valid
      if (_currentPage >= _totalPages) {
        _currentPage = math.max(0, _totalPages - 1);
        _pageController.jumpToPage(_currentPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadThemeFiles() {
    if (widget.iconThemeDir != null) {
      try {
        final dir = Directory(widget.iconThemeDir!);
        if (dir.existsSync()) {
          _themeFiles = dir
              .listSync(recursive: true)
              .whereType<File>()
              .toList();
        }
      } catch (e) {
        // ignore errors and fall back to original icons
      }
    }
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        return Container(
          width: _kDotSize,
          height: _kDotSize,
          margin: EdgeInsets.symmetric(horizontal: _kDotSpacing / 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Colors.blue
                // ignore: deprecated_member_use
                : Colors.grey.withOpacity(0.5),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final now = DateTime.now();
                if (_isScrolling &&
                    now.difference(_lastScrollTime).inMilliseconds < 300) {
                  return;
                }
                _isScrolling = true;
                _lastScrollTime = now;

                if (pointerSignal.scrollDelta.dy > 0 &&
                    _currentPage < _totalPages - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else if (pointerSignal.scrollDelta.dy < 0 &&
                    _currentPage > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }

                Future.delayed(const Duration(milliseconds: 300), () {
                  _isScrolling = false;
                });
              }
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              itemCount: _totalPages,
              itemBuilder: (context, pageIndex) {
                final startIndex = pageIndex * itemsPerPage;
                if (startIndex >= widget.apps.length) {
                  return const SizedBox.shrink();
                }
                final endIndex = math.min(startIndex + itemsPerPage, widget.apps.length);
                final pageApps = widget.apps.sublist(startIndex, endIndex);

                return Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: size.width * 0.083,
                        right: size.width * 0.083,
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(4),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 1.6,
                            ),
                        itemCount: pageApps.length,
                        itemBuilder: (context, index) {
                          final e = pageApps[index];
                          return GestureDetector(
                            onSecondaryTapUp:
                                (widget.onPin == null &&
                                    widget.onInstall == null &&
                                    widget.onCreateShortcut == null &&
                                    widget.onLaunchWithExternalGPU == null)
                                ? null
                                : (details) {
                                    final RenderBox overlay =
                                        Overlay.of(
                                              context,
                                            ).context.findRenderObject()
                                            as RenderBox;
                                    final position = RelativeRect.fromRect(
                                      Rect.fromPoints(
                                        details.globalPosition,
                                        details.globalPosition,
                                      ),
                                      Offset.zero & overlay.size,
                                    );

                                    final List<PopupMenuEntry> menuItems = [];

                                    if (widget.onPin != null) {
                                      menuItems.add(
                                        PopupMenuItem(
                                          child: const Text('Pin to dock'),
                                          onTap: () {
                                            Navigator.of(context).maybePop();
                                            widget.onPin?.call(e);
                                          },
                                        ),
                                      );
                                    }

                                    if (widget.onInstall != null) {
                                      menuItems.add(
                                        PopupMenuItem(
                                          child: const Text(
                                            'Uninstall this app',
                                          ),
                                          onTap: () {
                                            Navigator.of(context).maybePop();
                                            widget.onInstall?.call(e);
                                          },
                                        ),
                                      );
                                    }

                                    if (widget.onCreateShortcut != null) {
                                      menuItems.add(
                                        PopupMenuItem(
                                          child: const Text(
                                            'Create desktop shortcut',
                                          ),
                                          onTap: () {
                                            Navigator.of(context).maybePop();
                                            widget.onCreateShortcut?.call(e);
                                          },
                                        ),
                                      );
                                    }

                                    if (widget.onLaunchWithExternalGPU !=
                                        null) {
                                      menuItems.add(
                                        PopupMenuItem(
                                          child: const Text(
                                            'Run with external GPU',
                                          ),
                                          onTap: () {
                                            Navigator.of(context).maybePop();
                                            widget.onLaunchWithExternalGPU
                                                ?.call(e);
                                          },
                                        ),
                                      );
                                    }

                                    showMenu(
                                      context: context,
                                      position: position,
                                      items: menuItems,
                                    );
                                  },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => widget.onLaunch(e),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(0, 0, 0, 0),
                                  border: Border.all(color: Colors.transparent),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        String? themedPath;
                                        if (_themeFiles.isNotEmpty) {
                                          try {
                                            final candidates = <String>{};
                                            if (e.iconPath != null &&
                                                e.iconPath!.isNotEmpty) {
                                              final raw = e.iconPath!;
                                              final fn = raw
                                                  .split(Platform.pathSeparator)
                                                  .last;
                                              final dot = fn.lastIndexOf('.');
                                              final base = dot > 0
                                                  ? fn.substring(0, dot)
                                                  : fn;
                                              candidates.add(
                                                base.toLowerCase(),
                                              );
                                            }
                                            final nameBase = e.name
                                                .toLowerCase();
                                            candidates.add(nameBase);
                                            candidates.add(
                                              nameBase.replaceAll(' ', '-'),
                                            );
                                            candidates.add(
                                              nameBase.replaceAll(' ', '_'),
                                            );
                                            candidates.add(
                                              nameBase.replaceAll(' ', ''),
                                            );

                                            for (final f in _themeFiles) {
                                              final fn = f.path
                                                  .split(Platform.pathSeparator)
                                                  .last;
                                              final dot = fn.lastIndexOf('.');
                                              final base = dot > 0
                                                  ? fn.substring(0, dot)
                                                  : fn;
                                              final low = base.toLowerCase();
                                              if (candidates.contains(low) ||
                                                  candidates.any(
                                                    (c) => fn
                                                        .toLowerCase()
                                                        .contains(c),
                                                  )) {
                                                themedPath = f.path;
                                                break;
                                              }
                                            }
                                          } catch (_) {
                                            themedPath = null;
                                          }
                                        }

                                        if (themedPath != null) {
                                          if (themedPath.toLowerCase().endsWith(
                                            '.svg',
                                          )) {
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: SvgPicture.file(
                                                File(themedPath),
                                                width: 64,
                                                height: 64,
                                              ),
                                            );
                                          }

                                          return CircleAvatar(
                                            backgroundColor: Colors.transparent,
                                            radius: 32,
                                            backgroundImage: FileImage(
                                              File(themedPath),
                                            ),
                                          );
                                        }

                                        if (e.iconPath == null) {
                                          return const Icon(
                                            Icons.apps,
                                            size: 64,
                                          );
                                        }

                                        if (e.isSvgIcon) {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: SvgPicture.file(
                                              File(e.iconPath!),
                                              width: 64,
                                              height: 64,
                                            ),
                                          );
                                        }

                                        return CircleAvatar(
                                          backgroundColor: Colors.transparent,
                                          radius: 32,
                                          backgroundImage: FileImage(
                                            File(e.iconPath!),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      e.name,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_totalPages > 1) ...[
                      // Left arrow
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _currentPage > 0
                              ? IconButton(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 10,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.arrow_circle_left_rounded,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      // Right arrow
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _currentPage < _totalPages - 1
                              ? IconButton(
                                  onPressed: () {
                                    _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 10,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.arrow_circle_right_rounded,
                                    color: Colors.white70,
                                    size: 48,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: _buildPageIndicator(),
          ),
      ],
    );
  }
}
