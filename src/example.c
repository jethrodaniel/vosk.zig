// Copyright 2020, Nickolay V. Shmyrev
// Copyright 2023-present, Mark Delk
// SPDX-License-Identifier: Apache-2.0
//
// NOTE: Adapted from
//   https://github.com/alphacep/vosk-api/blob/aba84973b188bac259b2914cbb1455c6c68dd9b6/c/test_vosk.c
// which is licensed as Apache-2.0

#include <stdio.h>
#include <vosk_api.h>

int main(int argc, char **argv) {
  FILE *wavin;
  char buf[3200];
  int nread, final;

  VoskModel *model = vosk_model_new(argv[1]);
  VoskRecognizer *recognizer = vosk_recognizer_new(model, 16000.0);

  wavin = fopen(argv[2], "rb");
  fseek(wavin, 44, SEEK_SET);
  while (!feof(wavin)) {
    nread = fread(buf, 1, sizeof(buf), wavin);
    final = vosk_recognizer_accept_waveform(recognizer, buf, nread);
    if (final) {
      printf("%s\n", vosk_recognizer_result(recognizer));
    } else {
      printf("%s\n", vosk_recognizer_partial_result(recognizer));
    }
  }
  printf("%s\n", vosk_recognizer_final_result(recognizer));

  vosk_recognizer_free(recognizer);
  vosk_model_free(model);
  fclose(wavin);
  return 0;
}
