#!/usr/bin/env python
# -*- coding: utf-8 -*-

import numpy as np, matplotlib.pyplot as plt, pylab as p, time, sys
from scipy.spatial import ConvexHull
from scipy.stats import pearsonr

class snapshot:
    def __init__(self):
        self.interval = 0
        self.id = 0
        self.points = 0
        self.area = 0
        self.peso_prom = 0
        self.hull = 0

class interval:
    def __init__(self):
        self.id = 0
        self.agents = 0

def get_intervals(inter):
    # extraigo del csv las marcas
    m = np.loadtxt(open("salida-movimientos.csv","rb"),delimiter=";",skiprows=0)

    # busco la cantidad de ranas y el ultimo tic
    # sumo 1 por el index empieza en 0
    cant_ranas = m[:,1].max() + 1
    max_tic = m[:, 0].max() + 1

    # divido el csv por la cantidad de intervalos
    # notese que el csv ya está ordenado por tics
    matrix_by_intervals = np.vsplit(m, int(inter))

    # vector vacío para devolver los intervalos
    intervals = np.zeros(len(matrix_by_intervals), dtype=object)

    i = 0
    for m in matrix_by_intervals:
        # ordeno el intervalo por id de agente
        interval_by_agents = m[np.argsort(m[:,1])]
        
        # divido por la cantidad de agentes
        interval_by_agents = np.vsplit(interval_by_agents, cant_ranas)

        # vector vacío para ir procesando agentes de un intervalo
        agents_interval = np.zeros(len(interval_by_agents), dtype=object)
        j = 0
        
        # proceso cada agente en un objeto snapshot
        for a in interval_by_agents:
            s = snapshot()
            s.interval = i
            s.id = int(a[0, 1])
            s.peso_prom = np.average(a[:, 4])
            s.points = a[:, [2,3]].astype(int)
            agents_interval[j] = s
            j = j + 1

        inter = interval()
        inter.id = i
        inter.agents = agents_interval
        intervals[i] = inter
        i = i + 1    
    return intervals

def poly_area(x, y):
    n = len(x)
    area = 0.0
    for i in range(n):
        j = (i + 1) % n
        area += x[i] * y[j]
        area -= x[j] * y[i]
    area = abs(area) / 2.0
    return area
          
def process_interval(i):
    for agent in i.agents:
        agent = process_snap(agent)
        
def process_snap(s):
    points = s.points
    hull = ConvexHull(points)
    s.hull = hull
    s.area = poly_area(points[hull.vertices, 0], points[hull.vertices, 1])
    return s

def plot_intervals(i):
    for interval in i:
        plt.figure(interval.id)
        for agent in interval.agents:
            points = agent.points
            hull = agent.hull
            plt.plot(points[:,0], points[:,1], 'o')
            for simplex in hull.simplices:
                plt.plot(points[simplex, 0], points[simplex, 1], 'k-')
    plt.show()

if __name__ == "__main__":
    inter = sys.argv[1]
    intervals = get_intervals(inter)

    c = 0
    coeficientes = []
    for interval in intervals:
        process_interval(interval)

    for i in intervals:
        print("Momento #" + str(i.id))
        l = len(i.agents)
        area = np.zeros(l)
        peso = np.zeros(l)
        
        for x in range(0, l):
            area[x] = i.agents[x].area
            peso[x] = i.agents[x].peso_prom
            print("Rana #" + str(x) + " Condición: " + str(peso[x])  + " Area: " + str(area[x]) + "dm² " + "(" + str(area[x]/10) + "m²)" )
        p = pearsonr(peso, area)
        coeficientes.append([i.id, p[0]])
        #plt.figure(i.id)
        #plt.scatter(area, peso)

        print("Coeficiente corr iter#" + str(i.id) + " condición, área: " +  str(p[0]) + "\n")
    plt.plot(*zip(*coeficientes), marker='o', color='r', ls='')
    plt.figure(2)
    plt.plot(*zip(*coeficientes))
    plt.show() 
    #plot_intervals(intervals)
