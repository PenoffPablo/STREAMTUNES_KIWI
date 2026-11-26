-- ----------------------------------------------------------------------
-- El bucket 'audio' acepta los mismos formatos que deja elegir la app
--
-- La app permite subir MP3, M4A y WAV, pero el bucket solo aceptaba
-- 'audio/mpeg' (MP3): Storage rechazaba los M4A/WAV con 400 y el tema no se
-- publicaba. Se agregan los tipos MIME de M4A y WAV (con sus variantes más
-- comunes). El tope de 50 MB por archivo no cambia.
-- ----------------------------------------------------------------------
update storage.buckets
   set allowed_mime_types = array[
         'audio/mpeg', 'audio/mp3',                           -- MP3
         'audio/mp4', 'audio/x-m4a', 'audio/m4a', 'audio/aac', -- M4A / AAC
         'audio/wav', 'audio/x-wav', 'audio/wave'              -- WAV
       ],
       file_size_limit = 52428800
 where id = 'audio';
