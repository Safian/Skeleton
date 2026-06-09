import 'package:skeleton_shared/skeleton_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../blocs/admin/admin_cubit.dart';

class DocumentsTab extends StatefulWidget {
  const DocumentsTab({super.key});

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  String _selectedDocId = 'terms';
  String _selectedDocLang = 'hu';
  bool _enableFormatting = false;
  String _lastLoadedKey = '';
  final _docTitleCtrl = TextEditingController();
  final _docContentCtrl = TextEditingController();
  final _docVersionCtrl = TextEditingController();
  bool _isSavingDoc = false;

  @override
  void dispose() {
    _docTitleCtrl.dispose();
    _docContentCtrl.dispose();
    _docVersionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state is AdminLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AdminError) {
          return Center(
            child: Text(state.message, style: const TextStyle(color: Colors.red)),
          );
        }
        if (state is! AdminLoaded) {
          return const SizedBox.shrink();
        }

        // Ensure selected doc exists in the state list, or default to terms
        final validDocId = state.legalDocuments.any((d) => d.id == _selectedDocId)
            ? _selectedDocId
            : 'terms';

        if (_selectedDocId != validDocId) {
          _selectedDocId = validDocId;
        }

        final syncKey = '${validDocId}_$_selectedDocLang';
        if (_lastLoadedKey != syncKey) {
          final doc = state.legalDocuments.firstWhere(
            (d) => d.id == validDocId && d.isActive,
            orElse: () => state.legalDocuments.firstWhere(
              (d) => d.id == validDocId,
              orElse: () => LegalDocument(
                id: validDocId,
                titleLocales: {},
                contentLocales: {},
                updatedAt: DateTime.now(),
              ),
            ),
          );
          _docTitleCtrl.text = doc.titleLocales[_selectedDocLang] as String? ?? '';
          _docContentCtrl.text = doc.contentLocales[_selectedDocLang] as String? ?? '';
          _docVersionCtrl.text = doc.version;
          _lastLoadedKey = syncKey;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Szabályzatok és ÁSZF szerkesztése',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Itt szerkesztheted az Általános Szerződési Feltételeket és az Adatvédelmi nyilatkozatot több nyelven.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Selectors
                  _buildSelectors(state, isWide),
                  const SizedBox(height: AppSpacing.lg),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildDocEditorSection(state),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 4,
                          child: _buildDocPreviewSection(),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDocEditorSection(state),
                        const SizedBox(height: AppSpacing.lg),
                        _buildDocPreviewSection(),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectors(AdminLoaded state, bool isWide) {
    final langCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NYELV', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDocLang,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 'hu', child: Text('HU 🇭🇺')),
            DropdownMenuItem(value: 'en', child: Text('EN 🇬🇧')),
            DropdownMenuItem(value: 'de', child: Text('DE 🇩🇪')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedDocLang = val);
            }
          },
        ),
      ],
    );

    final docTypeCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DOKUMENTUM TÍPUSA', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDocId,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 'terms', child: Text('ÁSZF (terms)')),
            DropdownMenuItem(value: 'privacy', child: Text('Adatvédelem (privacy)')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedDocId = val);
            }
          },
        ),
      ],
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: langCol),
          const SizedBox(width: 16),
          Expanded(child: docTypeCol),
        ],
      );
    } else {
      return Column(
        children: [
          langCol,
          const SizedBox(height: 12),
          docTypeCol,
        ],
      );
    }
  }

  Widget _buildDocEditorSection(AdminLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DOKUMENTUM CÍME', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _docTitleCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Cím pl. Általános Szerződési Feltételek',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppColors.surface,
                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white10), borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VERZIÓSZÁM', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _docVersionCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'pl. 1.0',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: AppColors.surface,
                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white10), borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SZÖVEG TARTALMA', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
            Row(
              children: [
                const Text('Formázó eszköztár', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(width: 6),
                Switch(
                  value: _enableFormatting,
                  onChanged: (val) => setState(() => _enableFormatting = val),
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_enableFormatting) _buildFormattingToolbar(),
        TextField(
          controller: _docContentCtrl,
          maxLines: 15,
          minLines: 8,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Szöveg tartalma (HTML formázás támogatott)...',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white10), borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary), borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.background,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSavingDoc ? null : () => _saveDocument(state),
          child: _isSavingDoc
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.save, size: 18),
                    SizedBox(width: 8),
                    Text('Dokumentum Mentése', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildFormattingToolbar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _toolbarBtn('B', 'Félkövér', () => _insertTag('<b>', '</b>')),
          _toolbarBtn('I', 'Dőlt', () => _insertTag('<i>', '</i>')),
          _toolbarBtn('Balra', 'Balra igazít', () => _insertTag('<div align="left">', '</div>')),
          _toolbarBtn('Középre', 'Középre igazít', () => _insertTag('<div align="center">', '</div>')),
          _toolbarBtn('Jobbra', 'Jobbra igazít', () => _insertTag('<div align="right">', '</div>')),
          _toolbarBtn('Méret', 'Betűméret (20px)', () => _insertTag('<font size="20">', '</font>')),
          _toolbarBtn('Típus', 'Betűtípus', () => _insertTag('<font face="sans-serif">', '</font>')),
          _toolbarBtn('⏎', 'Új sor', () => _insertTag('<br/>', '')),
        ],
      ),
    );
  }

  Widget _toolbarBtn(String label, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          foregroundColor: Colors.white,
          minimumSize: const Size(40, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _insertTag(String openTag, String closeTag) {
    final text = _docContentCtrl.text;
    final selection = _docContentCtrl.selection;
    final start = selection.start >= 0 ? selection.start : 0;
    final end = selection.end >= 0 ? selection.end : 0;

    final selectedText = text.substring(start, end);
    final replacement = '$openTag$selectedText$closeTag';
    
    _docContentCtrl.text = text.replaceRange(start, end, replacement);
    _docContentCtrl.selection = TextSelection.collapsed(offset: start + openTag.length + selectedText.length);
    setState(() {});
  }

  Widget _buildDocPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ÉLES ELŐNÉZET', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 250, maxHeight: 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_docTitleCtrl.text.isNotEmpty) ...[
                  Text(
                    _docTitleCtrl.text,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                ],
                HtmlPreviewWidget(htmlText: _docContentCtrl.text),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveDocument(AdminLoaded state) async {
    final adminCubit = context.read<AdminCubit>();
    setState(() => _isSavingDoc = true);
    try {
      final doc = state.legalDocuments.firstWhere(
        (d) => d.id == _selectedDocId && d.isActive,
        orElse: () => state.legalDocuments.firstWhere(
          (d) => d.id == _selectedDocId,
          orElse: () => LegalDocument(
            id: _selectedDocId,
            titleLocales: {},
            contentLocales: {},
            updatedAt: DateTime.now(),
          ),
        ),
      );

      final finalTitleLocales = Map<String, dynamic>.from(doc.titleLocales);
      final finalContentLocales = Map<String, dynamic>.from(doc.contentLocales);

      finalTitleLocales[_selectedDocLang] = _docTitleCtrl.text;
      finalContentLocales[_selectedDocLang] = _docContentCtrl.text;

      final updatedDoc = LegalDocument(
        id: _selectedDocId,
        version: _docVersionCtrl.text.trim().isNotEmpty ? _docVersionCtrl.text.trim() : '1.0',
        isActive: true,
        titleLocales: finalTitleLocales,
        contentLocales: finalContentLocales,
        updatedAt: DateTime.now(),
      );

      await adminCubit.updateLegalDocument(updatedDoc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumentum sikeresen elmentve!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba a mentés során: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDoc = false);
      }
    }
  }
}
