import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../providers/music_provider.dart';
import '../../../utils/snackbar_util.dart';

class PlayerPlaylistSheet extends StatelessWidget {
  final MusicProvider musicProvider;

  const PlayerPlaylistSheet({required this.musicProvider, super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            _buildHeader(context),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: musicProvider.playlist.length,
                itemBuilder: _buildPlaylistItem,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '播放列表 (${musicProvider.playlist.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: () {
              musicProvider.clearPlaylist();
              Navigator.pop(context);
              AppSnackBar.show('播放列表已清空');
            },
            child: Text(
              '清空',
              style: TextStyle(color: Colors.red.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(BuildContext context, int index) {
    final song = musicProvider.playlist[index];
    final isPlaying = musicProvider.currentSong?.id == song.id;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: CachedNetworkImageProvider(song.r2CoverUrl ?? song.coverUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: isPlaying
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.equalizer_rounded, color: Colors.white, size: 24),
              )
            : null,
      ),
      title: Text(
        song.title,
        style: TextStyle(
          color: isPlaying ? Colors.orange : Colors.white,
          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => musicProvider.removeFromPlaylist(index),
      ),
      onTap: () {
        unawaited(musicProvider.playSong(song, playlist: musicProvider.playlist));
        Navigator.pop(context);
      },
    );
  }
}
