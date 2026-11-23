# Examen DBCA bifactorial — respuestas modelo (preguntas 0 a 20)

> Caso de ejemplo: engorde de truchas en jaulas del lago Titicaca. Los datos son simulados (semilla 2026) y todas las cifras se calcularon en R. Si tu caso es otro, cambia los nombres y vuelve a sacar las cifras con tu artefacto.

---

## Parte 0. Caso y datos

- **Objetivo:** determinar qué dieta (A) y qué densidad de siembra (B), y qué combinación de ambas, dan el mayor peso final de la trucha arcoíris en jaulas del lago Titicaca.
- **Variable respuesta:** peso medio final por jaula (g).
- **Factor A, dieta (fijo):** D1 = 38 % de proteína, D2 = 42 %, D3 = 46 % (a = 3).
- **Factor B, densidad de siembra (fijo):** P1 = baja, P2 = alta (b = 2).
- **Bloqueo:** lote de alevinos de origen (L1 a L4), porque cada lote llega con distinta talla y peso inicial. Son r = 4 bloques.
- Cada bloque tiene las 6 combinaciones A×B, una jaula por combinación, asignadas al azar dentro del bloque.
- N = a·b·r = 3·2·4 = **24 jaulas**.

**Tabla de datos (g)**

| Bloque | D1P1 | D1P2 | D2P1 | D2P2 | D3P1 | D3P2 | Total |
|---|---|---|---|---|---|---|---|
| L1 | 372 | 342 | 399 | 383 | 423 | 370 | 2289 |
| L2 | 371 | 351 | 407 | 389 | 433 | 391 | 2342 |
| L3 | 382 | 364 | 396 | 409 | 448 | 406 | 2405 |
| L4 | 386 | 379 | 420 | 407 | 442 | 422 | 2456 |
| **Total** | 1511 | 1436 | 1622 | 1588 | 1746 | 1589 | **9492** |
| **Media** | 377.75 | 359.00 | 405.50 | 397.00 | 436.50 | 397.25 | 395.50 |

Medias de dieta: D1 = 368.375, D2 = 401.250, D3 = 416.875.
Medias de densidad: P1 = 406.583, P2 = 384.417.
Medias de bloque: L1 = 381.50, L2 = 390.33, L3 = 400.83, L4 = 409.33.

---

## I. Fundamentos, caso y objetivo

**1. 📝** El DBCA con arreglo factorial de dos factores reúne las unidades experimentales en bloques homogéneos. Dentro de cada bloque se aplican **todas** las combinaciones de los niveles de A y de B (a·b tratamientos), asignadas al azar en cada bloque por separado. Cada bloque funciona como una repetición completa, así que con r ≥ 2 bloques cada combinación tiene r repeticiones.

Mi caso necesita bloques porque las jaulas no parten iguales: los alevinos de cada lote llegan con distinta talla y peso inicial, y eso cambia el peso final sin importar la dieta ni la densidad. El bloque controla esa variabilidad entre lotes. Al sacarla del error, el CME baja y las pruebas F de A, B y A×B son más potentes.

**2. 📝**
- El **factor de tratamiento** (dieta, densidad) es el que me interesa evaluar, y sus niveles los asigno yo al azar.
- El **factor de bloqueo** (lote) es una fuente de variación que no me interesa estudiar. Solo la controlo para que no infle el error, y no se asigna al azar: el lote es una característica que la jaula ya trae.
- **Cruzados:** cada nivel de A aparece con cada nivel de B. **Anidados:** los niveles de un factor existen solo dentro de un nivel del otro (por ejemplo, jaulas dentro de un lote).
- En mi caso A y B están **cruzados**, porque las 3 dietas se prueban con las 2 densidades (las 6 combinaciones existen en cada bloque).
- El bloque **no es un tratamiento**: no lo aplico ni lo voy a recomendar; solo agrupa unidades parecidas.
- Si analizara los datos como un **DCA**, sin el bloque, la SC de bloques (2655) pasaría al error. El CME subiría de 64.3 a (964.5 + 2655)/(15 + 3) = 201.1, las F bajarían y podría no detectar efectos que sí existen (error de tipo II). Además estaría violando la independencia, porque las jaulas del mismo lote se parecen entre sí.

**3. 📝** Objetivo: determinar la dieta, la densidad y la combinación dieta × densidad que maximizan el peso final por jaula de la trucha arcoíris, controlando el efecto del lote de alevinos. Variable respuesta: peso final (g). Factor A, dieta: D1, D2, D3. Factor B, densidad: P1 baja, P2 alta. Bloque: lote de alevinos, 4 bloques (L1 a L4).

---

## II. Esquema

**4. 💻** Resumen de la estructura que da el artefacto: niveles de A = 3, niveles de B = 2, bloques = 4, tratamientos a·b = 6, observaciones por celda A×B = 4 (una por bloque), observaciones por bloque = 6, N = 24.

Esquema: **Bloque (L1 a L4) > 6 combinaciones A×B > 1 jaula por combinación**.
- **Unidad experimental:** la jaula. Los 10 peces que se pesan son submuestras; se promedian en un solo dato por jaula.
- **Réplicas verdaderas:** los 4 bloques.
- **Balance:** el diseño es balanceado, porque todas las celdas tienen el mismo número de datos (4) y cada bloque tiene las 6 combinaciones.

**5. 📝**
- **Aleatorización:** en cada lote numeré las 6 jaulas del 1 al 6 y sorteé (con `sample()` o una tabla de números aleatorios) cuál combinación iba en cada jaula. Hice un sorteo independiente en cada bloque.
- **Formación de los bloques:** agrupé las jaulas por lote de alevinos de origen, de modo que las jaulas de un mismo bloque tienen peces de talla y peso inicial parecidos (homogéneas dentro del bloque y distintas entre bloques).
- **Pseudorreplicación:** la unidad es la jaula, no el pez. Los 10 peces pesados por jaula son submuestras y se promedian en un solo dato. Así, las repeticiones reales son los 4 bloques y no hay 40 "repeticiones" falsas por celda.

---

## III. Modelo e hipótesis

**6. 📝** Modelo:

y_ijk = μ + A_i + B_j + (AB)_ij + ρ_k + ε_ijk, con i = 1, 2, 3 (dietas), j = 1, 2 (densidades) y k = 1, …, 4 (bloques).

- y_ijk: peso final de la jaula con la dieta i y la densidad j en el lote k.
- μ: media general del peso.
- A_i: efecto de la dieta i (Σ A_i = 0).
- B_j: efecto de la densidad j (Σ B_j = 0).
- (AB)_ij: efecto de la interacción dieta × densidad.
- ρ_k: efecto del bloque (lote) k.
- ε_ijk: error experimental.

**Tipo de efecto:** A y B son **fijos**, porque la empresa eligió esas dietas y densidades y las conclusiones valen solo para ellas. El bloque es **aleatorio**, porque los lotes son una muestra de los que podrían llegar: ρ_k ~ N(0, σ²_ρ). Si solo interesaran esos 4 lotes, se tomaría como fijo, y la F sería la misma.

**Supuestos:** ε_ijk ~ N(0, σ²), independientes, con varianza constante en las 6 combinaciones.

**Sin interacción bloque × tratamiento (aditividad):** con una sola jaula por combinación en cada bloque, la interacción bloque × tratamiento no se puede separar del error: tiene los mismos gl, (ab − 1)(r − 1) = 15. Por eso se asume que el efecto del bloque es aditivo, es decir, que un lote sube o baja todas las combinaciones por igual, y esa interacción pasa a ser el error.

**7. 📝** Con α = 0.05:
- **Dieta:** H0: A_1 = A_2 = A_3 = 0 (las tres dietas dan el mismo peso medio). H1: al menos una dieta tiene A_i ≠ 0.
- **Densidad:** H0: B_1 = B_2 = 0. H1: al menos un B_j ≠ 0.
- **Interacción:** H0: (AB)_ij = 0 para todo i, j (el efecto de la dieta no depende de la densidad). H1: al menos un (AB)_ij ≠ 0.
- **Bloques:** H0: σ²_ρ = 0 (los lotes no difieren). H1: σ²_ρ > 0. Esta prueba no busca recomendar un lote. Sirve para comprobar que el bloqueo era necesario, es decir, que los lotes sí son heterogéneos.

---

## IV. Sumas de cuadrados

**8. 📝💻** El **factor de corrección (FC)** es el término que se resta para medir las sumas de cuadrados respecto a la media general y no respecto a cero. Fórmula: FC = (Σy)²/N, con N = a·b·r. Se usa en todas las SC (SC = suma de cuadrados de totales / n.º de datos de cada total − FC).

FC = 9492² / 24 = 90 098 064 / 24 = **3 754 086**

SCT = Σy² − FC = 3 771 440 − 3 754 086 = **17 354**

La SCT es la variabilidad total del peso final de las 24 jaulas alrededor de la media general (395.5 g). Es la cantidad que el ANOVA reparte entre bloques, dieta, densidad, interacción y error.

**9. 💻**
- SC Bloques = Σ(total de cada bloque)²/(a·b) − FC = 22 540 446/6 − FC = **2655.00**, con gl r − 1 = 3.
- SC Dieta = Σ(total de cada dieta)²/(b·r) − FC = 30 111 134/8 − FC = **9805.75**, con gl a − 1 = 2.
- SC Densidad = Σ(total de cada densidad)²/(a·r) − FC = 45 084 410/12 − FC = **2948.17**, con gl b − 1 = 1.
- SC Tratamientos (las 6 celdas) = 15 071 282/4 − FC = 13 734.50.
- SC A×B = SC Trat − SC A − SC B = 13 734.50 − 9805.75 − 2948.17 = **980.58**, con gl (a − 1)(b − 1) = 2.
- SC Error = SCT − SC Bloques − SC Trat = 17 354 − 2655 − 13 734.5 = **964.50**, con gl (ab − 1)(r − 1) = 5·3 = 15.

**Comprobación:**
- SC: 2655 + 9805.75 + 2948.17 + 980.58 + 964.5 = 17 354 ✔
- gl: 3 + 2 + 1 + 2 + 15 = 23 = N − 1 ✔

**Cómo se determinan los gl:** cada fuente tiene tantos gl como niveles menos uno, porque al fijar la media se pierde un dato libre. La interacción multiplica los gl de A y de B. El error recibe lo que sobra del total: hay ab − 1 = 5 gl entre tratamientos y r − 1 = 3 entre bloques, y su cruce, (ab − 1)(r − 1) = 15, es la variación que no explican ni los tratamientos ni los bloques.

---

## V. Tabla ANOVA

**10. 💻**

| Fuente | gl | SC | CM | F | p | Cuadrado medio esperado |
|---|---|---|---|---|---|---|
| Bloques | 3 | 2655.00 | 885.00 | 13.76 | 0.00014 | σ² + 6σ²_ρ |
| Dieta (A) | 2 | 9805.75 | 4902.88 | 76.25 | < 0.0001 | σ² + 8·ΣA_i²/2 |
| Densidad (B) | 1 | 2948.17 | 2948.17 | 45.85 | < 0.0001 | σ² + 12·ΣB_j²/1 |
| A×B | 2 | 980.58 | 490.29 | 7.63 | 0.0052 | σ² + 4·Σ(AB)²_ij/2 |
| Error | 15 | 964.50 | 64.30 | | | σ² |
| Total | 23 | 17 354.00 | | | | |

**Denominador:** con A y B fijos y el bloque aleatorio pero aditivo, el cuadrado medio esperado de cada fuente es σ² más su propio efecto. Por eso el denominador de **todas** las F es el **CME = 64.3**: es el único término que contiene solo σ², igual a lo que queda en el numerador cuando H0 es cierta. Si A o B fueran aleatorios, la F de los efectos principales se dividiría entre el CM de A×B.

**11. 💻** Con α = 0.05 interpreto **primero la interacción**:
- **A×B:** F = 7.63, p = 0.0052 < 0.05, se rechaza H0. El efecto de la dieta depende de la densidad: la ventaja de D3 es grande con densidad baja y desaparece con densidad alta.
- Como A×B es significativa, los efectos principales no se interpretan solos. Se analizan los **efectos simples**: las dietas dentro de cada densidad y las densidades dentro de cada dieta (pregunta 15).
- **Dieta:** F = 76.25, p < 0.0001, se rechaza H0. Hay diferencias entre dietas, pero su tamaño cambia según la densidad.
- **Densidad:** F = 45.85, p < 0.0001, se rechaza H0. La densidad baja da más peso, sobre todo con D3.
- **Bloques:** F = 13.76, p = 0.00014, significativo. Los lotes sí difieren (de 381.5 g en L1 a 409.3 g en L4), así que el bloqueo fue acertado.

---

## VI. Supuestos

**12. 💻**

| Supuesto | Prueba o gráfico | Estadístico | p | Conclusión |
|---|---|---|---|---|
| Normalidad de residuos | Shapiro-Wilk y gráfico Q-Q | W = 0.954 | 0.335 | Cumple |
| Homogeneidad de varianzas (6 combinaciones) | Levene (mediana) | F(5, 18) = 1.40 | 0.272 | Cumple |
| | Bartlett | χ²(5) = 3.76 | 0.585 | Cumple |
| Aditividad bloque × tratamiento | Tukey de 1 gl y perfiles por bloque | F(1, 14) = 0.52 | 0.484 | Cumple |
| Independencia | Aleatorización y residuos frente al orden | — | — | Cumple |

En el gráfico de residuos frente a valores ajustados, los residuos van de −14.8 a 10.9 sin forma de embudo, y ningún residuo estandarizado pasa de |2.34|. En el gráfico de perfiles por bloque, las líneas de los 4 lotes son casi paralelas.

**13. 📝**
- **Varianzas distintas:** la F se vuelve poco fiable (se rechaza H0 más o menos de lo debido), sobre todo si los grupos tienen distinto tamaño. Las comparaciones de Bonferroni que usan el CME común también quedan mal calibradas.
- **Falta de aditividad:** si un lote responde distinto a cada combinación, esa interacción queda dentro del error. El CME se infla, las F de A, B y A×B se hacen más pequeñas y se pierde potencia.
- **Diseño desbalanceado** (por ejemplo, si muere una jaula): las SC dejan de sumar la SCT y dependen del orden en que entran los términos. Hay que usar SC tipo III, y los gl del error bajan.

Alternativas:
1. Transformar la respuesta (logaritmo o Box-Cox) para estabilizar la varianza y recuperar la aditividad.
2. Usar un modelo mixto (REML, con `lme4`) o mínimos cuadrados ponderados, que aceptan datos desbalanceados y varianzas distintas. También se puede estimar el dato perdido o usar una prueba no paramétrica (Friedman sobre las 6 combinaciones).

---

## VII. Comparaciones y eficiencia del bloqueo

**14. 📝**
- Con Bonferroni se comparan las medias de dieta, las de densidad y, **si A×B es significativa**, los **efectos simples**: dietas dentro de cada densidad y densidades dentro de cada dieta.
- Se usa el **CME = 64.3** con **gl = (ab − 1)(r − 1) = 15**. El error estándar de una diferencia es √(2·CME/n), con n = número de datos de cada media.
- El nivel de significancia se ajusta dividiendo entre el número de comparaciones: α' = α/m. Por ejemplo, 3 dietas dentro de 2 densidades dan m = 6 y α' = 0.05/6 = 0.0083.
- Cuando A×B es significativa no conviene leer los efectos principales solos, porque promedian situaciones distintas. "D3 es mejor" es cierto con densidad baja, pero no con densidad alta.
- Los **bloques no se comparan**, porque no son tratamientos: no se van a recomendar y solo se usaron para controlar variación.

**15. 💻** Como A×B es significativa, hago los efectos simples.

**Dietas dentro de cada densidad:** m = 6, α' = 0.0083, error estándar = √(2·64.3/4) = 5.67, t crítico = 3.036.

| Densidad | Comparación | Diferencia (g) | p ajustado | ¿Significativa? |
|---|---|---|---|---|
| P1 | D2 − D1 | 27.75 | 0.0012 | Sí |
| P1 | D3 − D1 | 58.75 | < 0.0001 | Sí |
| P1 | D3 − D2 | 31.00 | 0.0004 | Sí |
| P2 | D2 − D1 | 38.00 | < 0.0001 | Sí |
| P2 | D3 − D1 | 38.25 | < 0.0001 | Sí |
| P2 | D3 − D2 | 0.25 | 1.000 | No |

**Densidades dentro de cada dieta:** m = 3, α' = 0.0167.

| Dieta | Diferencia P1 − P2 (g) | p ajustado | ¿Significativa? |
|---|---|---|---|
| D1 | 18.75 | 0.014 | Sí |
| D2 | 8.50 | 0.464 | No |
| D3 | 39.25 | < 0.0001 | Sí |

Grupos con densidad baja: D3 (a) > D2 (b) > D1 (c). Con densidad alta: D3 = D2 (a) > D1 (b).

**Eficiencia relativa:**

ER = [(r − 1)·CMB + r(ab − 1)·CME] / [(rab − 1)·CME] = [3·885 + 4·5·64.3] / [23·64.3] = (2655 + 1286) / 1478.9 = **2.66**

El DBCA fue 2.66 veces más eficiente que un DCA. Para lograr la misma precisión sin bloques habría hecho falta unas 2.66 veces más jaulas (unas 64 en vez de 24). El bloqueo por lote sí valió la pena.

---

## VIII. Gráficos

**16. 💻**
- **Gráfico de interacción** (eje X: dieta; una línea por densidad):
  - Línea P1: 377.75 → 405.50 → 436.50.
  - Línea P2: 359.00 → 397.00 → 397.25.
- **Efecto de A:** el peso sube de D1 a D3.
- **Efecto de B:** la línea P1 queda siempre por encima de P2.
- **Interacción:** las líneas no son paralelas. Se separan en D3, donde la línea P2 se aplana y la P1 sigue subiendo. No llegan a cruzarse, pero el abanico basta para que A×B sea significativa (p = 0.0052).
- **Qué indicaría un cruce:** que el orden de los niveles se invierte (por ejemplo, una dieta mejor con densidad baja y peor con densidad alta). Es la interacción más fuerte posible y daría un p de A×B muy pequeño. Si las líneas fueran paralelas, el p de A×B sería grande.
- **Cajas por combinación** (4 datos cada una):

| Combinación | Datos (g) | Amplitud (g) |
|---|---|---|
| D1P1 | 371–386 | 15 |
| D1P2 | 342–379 | 37 |
| D2P1 | 396–420 | 24 |
| D2P2 | 383–409 | 26 |
| D3P1 | 423–448 | 25 |
| D3P2 | 370–422 | 52 |

- **D3P1** tiene la caja más alta y una amplitud moderada.
- **D3P2** es la caja más ancha: con densidad alta, la dieta D3 es poco estable.
- Las cajas son más o menos simétricas y **no hay atípicos**. Parte de la amplitud se debe al lote, porque cada caja mezcla los 4 bloques.

---

## IX. Decisión

**17. 💻** Mejor dieta: **D3**. Mejor densidad: **P1 (baja)**. Mejor combinación: **D3P1**, con 436.5 g. Evidencias:
1. **ANOVA:** dieta, densidad y A×B son significativas, así que la decisión se toma por combinación.
2. **Bonferroni:** con P1, D3 supera a D2 por 31 g (p = 0.0004) y a D1 por 58.75 g (p < 0.0001). Dentro de D3, P1 supera a P2 por 39.25 g (p < 0.0001).
3. **Gráfico de interacción:** D3P1 es el punto más alto, y la línea P1 sigue subiendo hasta D3.
4. **Cajas:** la caja de D3P1 (423–448 g) es la más alta y su amplitud es moderada (25 g). D3P2 tiene una media mucho menor y la caja más ancha (52 g), así que es la menos confiable.

Si la empresa tuviera que trabajar con densidad alta, D2 y D3 serían equivalentes (diferencia de 0.25 g). Convendría D2, que tiene 4 puntos menos de proteína y probablemente cuesta menos.

---

## X. Ecuación y predicción

**18. 💻** Ejemplo con D3P1 (usa la combinación que te asigne el docente):
- Estimación: ŷ = 436.5 g. Se usa t(0.975; 15) = 2.131.
- **IC 95 % de la media:** EE = √(CME/r) = √(64.3/4) = 4.01, así que 436.5 ± 2.131·4.01 = **[427.95; 445.05] g**.
- **Intervalo de predicción 95 % (una jaula nueva):** EE = √(CME·(1 + 1/r)) = √(64.3·1.25) = 8.97, así que 436.5 ± 2.131·8.97 = **[417.39; 455.61] g**.

El intervalo de predicción es más ancho porque suma dos varianzas: la incertidumbre al estimar la media (σ²/r) y la variación propia de una jaula individual (σ², estimada por el CME). El IC solo incluye la primera. Si el lote de la nueva jaula es desconocido y se toma como aleatorio, habría que sumar además σ²_ρ = (885 − 64.3)/6 = 136.8.

**19. 💻** Ecuación estimada:

ŷ_ijk = 395.5 + Â_i + B̂_j + (AB)̂_ij + ρ̂_k

| Término | Valores estimados |
|---|---|
| Â_i (dieta) | D1 = −27.125; D2 = +5.750; D3 = +21.375 |
| B̂_j (densidad) | P1 = +11.083; P2 = −11.083 |
| (AB)̂_ij | D1P1 = −1.708; D2P1 = −6.833; D3P1 = +8.542 (los de P2 tienen el signo contrario) |
| ρ̂_k (bloque) | L1 = −14.000; L2 = −5.167; L3 = +5.333; L4 = +13.833 |

- **R² = 1 − SCE/SCT = 1 − 964.5/17 354 = 0.944.** El modelo explica el 94.4 % de la variación del peso final.
- **R² ajustado = 0.915.**
- Reparto de la SCT: dieta 56.5 %, densidad 17.0 %, bloques 15.3 %, A×B 5.7 % y error 5.6 %.
- Los bloques (lotes) explican el **15.3 %** de la variabilidad. Sin bloquear, ese porcentaje habría quedado en el error.
- Para validar la ecuación usé el gráfico Q-Q de residuos, el de residuos frente a valores ajustados, el de residuos por bloque y el de perfiles por bloque.

---

## XI. Artefacto

**20. 💻** Cambié el dato de **L2, D1P2: de 351 g a 420 g** (un atípico) y volví a correr el análisis.

| Resultado | Original | Con el atípico |
|---|---|---|
| F Bloques (p) | 13.76 (0.0001) | 3.57 (0.039) |
| F Dieta (p) | 76.25 (< 0.0001) | 13.65 (0.0004) |
| F Densidad (p) | 45.85 (< 0.0001) | 6.83 (0.020) |
| F A×B (p) | 7.63 (**0.005**) | 3.41 (**0.060**, ya no es significativa) |
| CME | 64.3 | 236.6 |
| R² / R² ajustado | 0.944 / 0.915 | 0.775 / 0.655 |
| Eficiencia relativa | 2.66 | 1.34 |
| Shapiro-Wilk (p) | 0.335 | **0.017** (falla la normalidad) |
| Levene (p) | 0.272 | 0.177 |
| Máx. residuo estandarizado | 2.34 | 3.31 (atípico) |

**Por qué ocurrió:** el dato atípico no encaja en el patrón aditivo (bloque + tratamiento), así que casi todo su desvío se va al **error**. El CME se multiplicó por 3.7 y, como es el denominador de todas las F, todas las F bajaron. La interacción dejó de ser significativa, el R² cayó y la eficiencia del bloqueo bajó porque el CME creció más que el CMB. Ese residuo grande también rompió la normalidad. Conclusión: un solo dato atípico puede cambiar la decisión, así que hay que revisar los residuos antes de recomendar.
