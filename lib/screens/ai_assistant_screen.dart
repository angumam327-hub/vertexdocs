import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/chat_message_model.dart';
import '../services/ai_assistant_service.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialPdfPath;

  const AiAssistantScreen({super.key, this.initialPdfPath});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiAssistantService _aiService = AiAssistantService();
  final StorageService _storage = StorageService();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  String _selectedLanguage = 'en'; // 'en' or 'ta'
  String? _currentlySpeakingMessageId;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _storage.getLanguage();
    _aiService.setLanguage(_selectedLanguage);
    _loadHistory();

    if (widget.initialPdfPath != null) {
      _loadPdf(widget.initialPdfPath!);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _aiService.stopSpeaking();
    super.dispose();
  }

  void _loadHistory() {
    final history = _storage.getChatHistory();
    if (history.isNotEmpty) {
      _messages = history;
    } else {
      _addInitialGreeting();
    }
  }

  void _addInitialGreeting() {
    final isTamil = _selectedLanguage == 'ta';
    _messages = [
      ChatMessageModel(
        id: 'welcome',
        text: isTamil
            ? 'வணக்கம்! நான் VertexDocs AI ஆவண உதவியாளர்.\n\nநீங்கள் எந்த PDF ஆவணத்தையும் பதிவேற்றி, அதன் சுருக்கம் பெறலாம், முக்கிய குறிப்புகளைப் பிரித்தெடுக்கலாம், அல்லது கேள்விகள் கேட்கலாம்.'
            : 'Welcome to VertexDocs AI Assistant!\n\nUpload any PDF to get instant summaries, extract actionable takeaways, simplify dense text, or chat directly with your document in English or Tamil.',
        isUser: false,
        timestamp: DateTime.now(),
        isDemo: true,
        language: _selectedLanguage,
        suggestedActions: const [
          'Summarize',
          'Key Points',
          'Explain Simply',
          'Extract Text',
        ],
      ),
    ];
  }

  Future<void> _loadPdf(String path) async {
    setState(() => _isLoading = true);
    await _aiService.loadPdf(path);
    if (!mounted) return;
    setState(() => _isLoading = false);

    _sendMessage(
      'Document "${_aiService.currentDocument?.name}" loaded. What would you like to know?',
      isSystemPrompt: true,
    );
  }

  Future<void> _pickPdf() async {
    final file = await FileService().pickSinglePdf();
    if (file != null) {
      await _loadPdf(file.path);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String query,
      {bool isSystemPrompt = false, String? promptType}) async {
    final text = query.trim();
    if (text.isEmpty) return;

    _textController.clear();

    if (!isSystemPrompt) {
      final userMessage = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        attachedPdfName: _aiService.currentDocument?.name,
        language: _selectedLanguage,
      );

      setState(() {
        _messages.add(userMessage);
        _isLoading = true;
      });
      _scrollToBottom();
    }

    try {
      final response = await _aiService.askAi(text, promptType: promptType);
      if (!mounted) return;

      setState(() {
        _messages.add(response);
        _isLoading = false;
      });
      _storage.saveChatHistory(_messages);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _toggleLanguage(String lang) {
    if (_selectedLanguage == lang) return;
    setState(() {
      _selectedLanguage = lang;
      _aiService.setLanguage(lang);
    });
    _addInitialGreeting();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _aiService.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _aiService.startListening(
        onResult: (text) {
          setState(() {
            _textController.text = text;
          });
        },
      );
    }
  }

  Future<void> _toggleTts(ChatMessageModel message) async {
    if (_currentlySpeakingMessageId == message.id) {
      await _aiService.stopSpeaking();
      setState(() => _currentlySpeakingMessageId = null);
    } else {
      setState(() => _currentlySpeakingMessageId = message.id);
      await _aiService.speakText(message.text);
      setState(() => _currentlySpeakingMessageId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _aiService.currentDocument;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'VertexDocs AI',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // English / Tamil Pill
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangChip('EN', 'en'),
                _buildLangChip('தமிழ்', 'ta'),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Clear Chat',
            onPressed: () {
              setState(() {
                _addInitialGreeting();
              });
              _storage.clearChatHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Document Status Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: doc != null
                        ? AppColors.secondary
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    doc != null
                        ? Icons.picture_as_pdf_rounded
                        : Icons.file_present_rounded,
                    color: doc != null
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc != null ? doc.name : 'No PDF attached for analysis',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        doc != null
                            ? '${doc.pageCount} Pages • ${FileUtils.formatBytes(doc.sizeInBytes)}'
                            : 'Attach a PDF below to ask contextual questions',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _pickPdf,
                  child: Text(
                    doc != null ? 'Change' : 'Choose PDF',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Action Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildQuickAction(
                    '📋 Summarize',
                    () => _sendMessage('Summarize this PDF',
                        promptType: 'summarize')),
                _buildQuickAction(
                    '⭐ Key Points',
                    () => _sendMessage('Extract key points',
                        promptType: 'key_points')),
                _buildQuickAction(
                    '💡 Explain Simply',
                    () => _sendMessage('Explain this simply',
                        promptType: 'explain_simple')),
                _buildQuickAction(
                    '📝 Extract Text',
                    () => _sendMessage('Extract all raw text',
                        promptType: 'extract_text')),
              ],
            ),
          ),

          // Chat Messages View
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedLanguage == 'ta'
                        ? 'AI பதிலளிக்கிறது...'
                        : 'Analyzing document...',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

          // Chat Input Row
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded,
                        color: AppColors.primary),
                    tooltip: 'Attach PDF',
                    onPressed: _pickPdf,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _selectedLanguage == 'ta'
                              ? 'PDF பற்றி கேள்வி கேட்கவும்...'
                              : 'Ask anything about this PDF...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 13, color: AppColors.textTertiary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (val) => _sendMessage(val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: _isListening
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    tooltip: 'Voice Input',
                    onPressed: _toggleVoiceInput,
                  ),
                  InkWell(
                    onTap: () => _sendMessage(_textController.text),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3DF23882),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLangChip(String label, String code) {
    final isSel = _selectedLanguage == code;
    return InkWell(
      onTap: () => _toggleLanguage(code),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.cardBorder),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: AppColors.buttonShadow,
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final isSpeaking = _currentlySpeakingMessageId == msg.id;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 32),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'VertexDocs AI',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    if (msg.isDemo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.secondaryBorder),
                        ),
                        child: Text(
                          'DEMO MODE',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isSpeaking
                        ? Icons.volume_up_rounded
                        : Icons.volume_mute_outlined,
                    size: 20,
                    color:
                        isSpeaking ? AppColors.primary : AppColors.textTertiary,
                  ),
                  onPressed: () => _toggleTts(msg),
                  tooltip: isSpeaking ? 'Stop speaking' : 'Listen',
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              msg.text,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
