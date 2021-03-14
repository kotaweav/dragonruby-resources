float* c_create_mat(int width, int rows) {
  return malloc(width * rows * sizeof(float*));
}

void c_free_mat(float* mat) {
  free(mat);
}

float* c_matmul(float* m1, int c1, int r1, float* m2, int c2, int r2) {
  float* res = malloc(r1 * c2 * sizeof(float));
  for (int i = 0; i < r1; ++i) {
    for (int j = 0; j < c2; ++j) {
      float sum = 0;
      for (int k = 0; k < c1; ++k) {
        sum += m1[i * c1 + k] * m2[c2 * k + j];
      }
      res[i * c2 + j] = sum;
    }
  }
  return res;
}
